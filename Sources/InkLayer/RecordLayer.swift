import AppKit
import ScreenCaptureKit
import AVFoundation
import UserNotifications

/// 讲一段录屏：Ctrl+5 即录/再按停 → 可播放 mp4（画面+麦克风）
/// 体验红线：大号计时条 + 系统通知，杜绝"没感觉/忘了还在录"
final class RecordLayer: NSObject, @unchecked Sendable {
    private var lifecycle = RecordingLifecycle()
    var isRecording: Bool { lifecycle.state == .recording }
    var onStateChange: ((Bool) -> Void)?
    var onNeedPermission: (() -> Void)?

    private var stream: SCStream?
    private var audioSession: AVCaptureSession?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false
    private var startedAt: Date?
    private var outputURL: URL?
    private var ticker: RecordTickerWindow?
    private let ioQueue = DispatchQueue(label: "inklayer.record.io")
    private var frameCount = 0
    private var expectedVideoSize: (Int, Int) = (0, 0)

    func toggle() {
        switch lifecycle.state {
        case .recording:
            stop()
        case .idle:
            start()
        case .starting, .stopping:
            break
        }
    }

    // MARK: - 启动

    func start() {
        guard lifecycle.state == .idle else { return }
        guard CGPreflightScreenCaptureAccess() else {
            Telemetry.shared.log("record.denied")
            onNeedPermission?()
            return
        }
        guard lifecycle.requestStart() else { return }
        Task { [weak self] in
            do {
                try await self?.boot()
            } catch {
                Telemetry.shared.log("record.error",
                                     ["error": error.localizedDescription])
                await MainActor.run { [weak self] in
                    self?.teardown(abort: true)
                }
            }
        }
    }

    private func boot() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "inklayer.record", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "无可用显示器"])
        }

        var micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            micOK = await AVCaptureDevice.requestAccess(for: .audio)
        }
        if !micOK { Telemetry.shared.log("record.mic_denied") }

        // H.264 要求偶数宽高
        let width = display.width - (display.width % 2)
        let height = display.height - (display.height % 2)

        let dir = ConfigStore.recordOutputDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = DateFormatter().then {
            $0.dateFormat = "yyyy-MM-dd HH.mm.ss"
        }.string(from: Date())
        let url = dir.appendingPathComponent("InkLayer \(stamp).mp4")

        let w = try AVAssetWriter(url: url, fileType: .mp4)
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ])
        vIn.expectsMediaDataInRealTime = true
        w.add(vIn)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vIn,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ])

        // 麦克风采样率：跟设备走，避免 44.1 vs 48 硬编码导致不可播
        var aIn: AVAssetWriterInput?
        var micDevice: AVCaptureDevice?
        if micOK {
            micDevice = AVCaptureDevice.default(for: .audio)
            let sampleRate = Self.deviceSampleRate(micDevice) ?? 48_000
            let channels = 1
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 128000
            ])
            input.expectsMediaDataInRealTime = true
            if w.canAdd(input) {
                w.add(input)
                aIn = input
            } else {
                Telemetry.shared.log("record.mic_denied", ["reason": "writer-reject-audio"])
                micOK = false
            }
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 8
        config.capturesAudio = false

        let sc = SCStream(filter: filter, configuration: config, delegate: nil)
        try sc.addStreamOutput(self, type: .screen, sampleHandlerQueue: ioQueue)

        var session: AVCaptureSession?
        if micOK, let dev = micDevice {
            let s = AVCaptureSession()
            if let src = try? AVCaptureDeviceInput(device: dev), s.canAddInput(src) {
                s.addInput(src)
                let out = AVCaptureAudioDataOutput()
                // 尽量让输出靠近 writer 期望的采样率
                out.setSampleBufferDelegate(self, queue: ioQueue)
                if s.canAddOutput(out) { s.addOutput(out); session = s }
            }
        }

        guard w.startWriting() else {
            throw w.error ?? NSError(domain: "inklayer.record", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "无法开始写入"])
        }

        self.writer = w
        self.videoInput = vIn
        self.audioInput = aIn
        self.pixelAdaptor = adaptor
        self.stream = sc
        self.audioSession = session
        self.outputURL = url
        self.sessionStarted = false
        self.startedAt = Date()
        self.frameCount = 0
        self.expectedVideoSize = (width, height)

        try await sc.startCapture()
        session?.startRunning()

        let micGranted = micOK
        await MainActor.run { [weak self] in
            guard let self else { return }
            guard self.lifecycle.didStart() else {
                self.teardown(abort: true)
                return
            }
            let t = RecordTickerWindow()
            t.onStop = { [weak self] in self?.stop() }
            t.orderFrontRegardless()
            t.startClock()
            self.ticker = t
            self.onStateChange?(true)
            Self.notify(title: "InkLayer 开始录制",
                        body: micGranted ? "含麦克风 · 再按 Ctrl+5 停止" : "无麦克风 · 再按 Ctrl+5 停止")
            Telemetry.shared.log("record.start", ["mic": micGranted ? "on" : "off"])
        }
    }

    /// 读取麦克风实际采样率（失败返回 nil）
    private static func deviceSampleRate(_ device: AVCaptureDevice?) -> Double? {
        guard let device else { return nil }
        let desc = device.activeFormat.formatDescription
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee else {
            return nil
        }
        let rate = asbd.mSampleRate
        return rate > 0 ? rate : nil
    }

    // MARK: - 停止

    func stop() {
        guard lifecycle.requestStop() else { return }
        let stream = self.stream
        let session = self.audioSession
        Task { [weak self] in
            try? await stream?.stopCapture()
            session?.stopRunning()
            await MainActor.run { [weak self] in self?.ticker?.shutdown() }
            self?.ioQueue.async { self?.seal() }
        }
    }

    private func seal() {
        guard let w = writer else {
            DispatchQueue.main.async { [weak self] in
                self?.teardown(abort: true)
            }
            return
        }
        // 0 帧也要 finish，避免 writer 悬挂
        if !sessionStarted {
            w.startSession(atSourceTime: .zero)
            sessionStarted = true
        }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        let url = outputURL
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let frames = frameCount
        w.finishWriting { [weak self] in
            let ok = w.status == .completed && frames > 0
            let attrs = try? FileManager.default.attributesOfItem(atPath: url?.path ?? "")
            let size = (attrs?[.size] as? Int) ?? 0
            if !ok {
                Telemetry.shared.log("record.error", [
                    "duration": String(format: "%.1f", duration),
                    "bytes": "\(size)",
                    "frames": "\(frames)",
                    "status": "\(w.status.rawValue)",
                    "error": w.error?.localizedDescription ?? "no-frames"
                ])
            } else {
                Telemetry.shared.log("record.stop", [
                    "duration": String(format: "%.1f", duration),
                    "bytes": "\(size)",
                    "frames": "\(frames)"
                ])
            }
            DispatchQueue.main.async {
                self?.teardown(abort: !ok)
                if ok, let url {
                    let mb = Double(size) / 1_048_576
                    Self.notify(title: "录制完成",
                                body: String(format: "%.1f 秒 · %.1f MB · 已在 Finder 中高亮", duration, mb))
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else if !ok {
                    Self.notify(title: "录制失败",
                                body: frames == 0 ? "未写入任何画面帧" : (w.error?.localizedDescription ?? "未知错误"))
                }
            }
        }
    }

    private func teardown(abort: Bool) {
        if abort, let url = outputURL { try? FileManager.default.removeItem(at: url) }
        stream = nil; audioSession = nil; writer = nil
        videoInput = nil; audioInput = nil; pixelAdaptor = nil
        ticker = nil; outputURL = nil; frameCount = 0
        sessionStarted = false
        lifecycle.didFinish()
        onStateChange?(false)
    }

    // MARK: - 帧写入

    private var lastVideoPTS: CMTime = .invalid

    private func appendVideo(_ sb: CMSampleBuffer) {
        guard let w = writer, let vIn = videoInput, let adaptor = pixelAdaptor else { return }
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }

        // 尺寸校验：与 writer 声明不一致则跳过（避免静默失败）
        let pw = CVPixelBufferGetWidth(pb)
        let ph = CVPixelBufferGetHeight(pb)
        let (ew, eh) = expectedVideoSize
        if ew > 0, eh > 0, (pw != ew || ph != eh) {
            // 允许 1px 误差（奇偶对齐）
            if abs(pw - ew) > 2 || abs(ph - eh) > 2 { return }
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
        // 按 PTS 节流约 30fps，保持时间轴连续
        if lastVideoPTS.isValid {
            let delta = CMTimeSubtract(pts, lastVideoPTS)
            if CMTimeGetSeconds(delta) < (1.0 / 30.0) - 0.001 { return }
        }

        if !sessionStarted {
            w.startSession(atSourceTime: pts)
            sessionStarted = true
        }
        guard vIn.isReadyForMoreMediaData else { return }
        if adaptor.append(pb, withPresentationTime: pts) {
            lastVideoPTS = pts
            frameCount += 1
        }
    }

    private func appendAudio(_ sb: CMSampleBuffer) {
        guard sessionStarted, let aIn = audioInput, aIn.isReadyForMoreMediaData else { return }
        aIn.append(sb)
    }

    private static func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
            center.add(req, withCompletionHandler: nil)
        }
        DispatchQueue.main.async { flashEdge() }
        NSSound.beep()
    }

    private static func flashEdge() {
        guard let screen = NSScreen.main else { return }
        let h: CGFloat = 6
        let w = NSWindow(contentRect: NSRect(x: screen.frame.minX,
                                             y: screen.frame.maxY - h,
                                             width: screen.frame.width, height: h),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = NSColor.systemRed
        w.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        w.sharingType = .readWrite
        w.ignoresMouseEvents = true
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.45
            w.animator().alphaValue = 0
        }, completionHandler: { w.orderOut(nil) })
    }
}

extension RecordLayer: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        appendVideo(sampleBuffer)
    }
}

extension RecordLayer: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        appendAudio(sampleBuffer)
    }
}

/// 角落计时条：更大、更显眼（体验红线）
final class RecordTickerWindow: NSWindow {
    private let label = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var startedAt = Date()
    var onStop: (() -> Void)?

    init() {
        let w: CGFloat = 168, h: CGFloat = 44
        let sf = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(contentRect: NSRect(x: sf.maxX - w - 20, y: sf.maxY - h - 12,
                                       width: w, height: h),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        sharingType = .readWrite
        ignoresMouseEvents = false

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.92).cgColor
        bg.layer?.cornerRadius = 12

        label.frame = NSRect(x: 14, y: 10, width: 90, height: 24)
        label.drawsBackground = false
        label.isBezeled = false

        let btn = NSButton(title: "停止", target: self, action: #selector(stopClicked))
        btn.frame = NSRect(x: 108, y: 8, width: 48, height: 28)
        btn.isBordered = false
        btn.contentTintColor = .white
        btn.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        btn.layer?.cornerRadius = 6

        bg.addSubview(label)
        bg.addSubview(btn)
        contentView = bg
        tick()
    }

    required init?(coder: NSCoder) { fatalError() }

    func startClock() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        orderOut(nil)
    }

    private func tick() {
        let s = Int(Date().timeIntervalSince(startedAt))
        let time = String(format: "%d:%02d", s / 60, s % 60)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        let attr = NSMutableAttributedString(
            string: "● \(time)",
            attributes: [.foregroundColor: NSColor.white, .font: font])
        label.attributedStringValue = attr
    }

    @objc private func stopClicked() { onStop?() }
}

private extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self); return self
    }
}
