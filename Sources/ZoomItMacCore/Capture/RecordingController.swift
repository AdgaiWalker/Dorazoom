import AVFoundation
import AppKit
import CoreImage
@preconcurrency import ScreenCaptureKit

/// Wraps a CMSampleBuffer so it can be handed from capture callbacks to the
/// writer queue. CMSampleBuffer is immutable once delivered and the writer
/// serialises all access.
private struct SampleBufferBox: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

private let recordingSyntheticFrameDuration = CMTime(value: 1, timescale: 10)

private struct RecordingImageFrame: @unchecked Sendable {
    let image: CGImage
    let presentationTime: CMTime
    let duration: CMTime

    init(image: CGImage, presentationTime: CMTime, duration: CMTime = recordingSyntheticFrameDuration) {
        self.image = image
        self.presentationTime = presentationTime
        self.duration = duration
    }
}

/// Owns the AVAssetWriter and serialises all sample appends on its own queue so
/// it can safely receive buffers from the ScreenCaptureKit and microphone
/// capture callbacks (which run on background queues).
private final class RecordingEngine: @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "com.zoomitmac.recorder")
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let systemAudioInput: AVAssetWriterInput?
    private let micInput: AVAssetWriterInput?
    private let profile: MovieRecordingProfile
    private let videoSettings: [String: Any]
    private let width: Int
    private let height: Int
    private var pauseTimeline = RecordingPauseTimeline()
    private var lastObservedSourceSeconds: TimeInterval?
    private var sessionStarted = false
    private var hasVideoSample = false
    private var systemAudioStarted = false
    private var micStarted = false
    private var lastVideoPresentationTime: CMTime?
    private var lastVideoDuration = recordingSyntheticFrameDuration
    private var finished = false

    init(url: URL, width: Int, height: Int, systemAudio: Bool, microphone: Bool, profile: MovieRecordingProfile) throws {
        self.url = url
        self.width = width
        self.height = height
        self.profile = profile
        writer = try AVAssetWriter(outputURL: url, fileType: profile.avFileType)
        writer.movieFragmentInterval = CMTime(
            seconds: RecordingFragmentPolicy.movieFragmentIntervalSeconds,
            preferredTimescale: 600
        )

        videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        if writer.canAdd(videoInput) { writer.add(videoInput) }

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: profile.audioChannelCount,
            AVSampleRateKey: profile.audioSampleRate,
            AVEncoderBitRateKey: profile.audioBitRate
        ]
        if systemAudio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = true
            systemAudioInput = writer.canAdd(input) ? input : nil
            if let systemAudioInput { writer.add(systemAudioInput) }
        } else {
            systemAudioInput = nil
        }
        if microphone {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = true
            micInput = writer.canAdd(input) ? input : nil
            if let micInput { writer.add(micInput) }
        } else {
            micInput = nil
        }
    }

    func startWriting() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.writer.startWriting()
                continuation.resume()
            }
        }
    }

    func setPaused(_ paused: Bool) {
        queue.async {
            let sourceTime = self.lastObservedSourceSeconds ?? 0
            if paused {
                _ = self.pauseTimeline.pause(atSourceTime: sourceTime)
            } else {
                _ = self.pauseTimeline.resume(atSourceTime: sourceTime)
            }
        }
    }

    func appendVideo(_ box: SampleBufferBox) {
        queue.async {
            guard !self.finished, self.writer.status == .writing,
                  let sampleBuffer = self.retimedVideoSampleBuffer(box.buffer) else { return }
            self.appendVideoOnQueue(sampleBuffer)
        }
    }

    func appendVideoImage(_ frame: RecordingImageFrame) {
        queue.async {
            guard !self.finished, self.writer.status == .writing else { return }
            guard let presentationTime = self.monotonicVideoPresentationTime(for: frame.presentationTime) else { return }
            guard let sampleBuffer = self.makeSampleBuffer(from: frame.image, presentationTime: presentationTime, duration: frame.duration) else { return }
            self.appendVideoOnQueue(sampleBuffer)
        }
    }

    func appendVideoImageIfNeeded(_ frame: RecordingImageFrame) {
        queue.async {
            guard !self.hasVideoSample, !self.finished, self.writer.status == .writing else { return }
            guard let presentationTime = self.monotonicVideoPresentationTime(for: frame.presentationTime) else { return }
            guard let sampleBuffer = self.makeSampleBuffer(from: frame.image, presentationTime: presentationTime, duration: frame.duration) else { return }
            self.appendVideoOnQueue(sampleBuffer)
        }
    }

    func appendVideoImageAtEnd(_ frame: RecordingImageFrame) {
        queue.async {
            guard !self.finished, self.writer.status == .writing else { return }
            guard let presentationTime = self.monotonicVideoPresentationTime(for: frame.presentationTime) else { return }
            guard let sampleBuffer = self.makeSampleBuffer(
                from: frame.image,
                presentationTime: presentationTime,
                duration: frame.duration
            ) else { return }
            self.appendVideoOnQueue(sampleBuffer)
        }
    }

    func appendBlackVideoFrameIfNeeded(presentationTime: CMTime) {
        queue.async {
            guard !self.hasVideoSample, !self.finished, self.writer.status == .writing,
                  let image = self.makeBlackImage(),
                  let mappedTime = self.monotonicVideoPresentationTime(for: presentationTime),
                  let sampleBuffer = self.makeSampleBuffer(from: image, presentationTime: mappedTime, duration: recordingSyntheticFrameDuration) else { return }
            self.appendVideoOnQueue(sampleBuffer)
        }
    }

    func waitForQueuedAppends() async {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume()
            }
        }
    }

    func appendSystemAudio(_ box: SampleBufferBox) {
        queue.async {
            guard self.sessionStarted, !self.finished, self.writer.status == .writing,
                  let input = self.systemAudioInput, input.isReadyForMoreMediaData else { return }
            // Avoid creating an entirely-silent track by dropping leading silent
            // buffers until the first real audio; once audio has started, append
            // every buffer (including later silence) so the timeline stays
            // continuous. Dropping silent buffers mid-stream punches gaps that
            // the AAC encoder turns into pops.
            if !self.systemAudioStarted {
                guard self.hasNonZeroAudioSamples(box.buffer) else { return }
                self.systemAudioStarted = true
            }
            guard let sampleBuffer = self.retimedAudioSampleBuffer(box.buffer) else { return }
            input.append(sampleBuffer)
        }
    }

    func appendMicrophone(_ box: SampleBufferBox) {
        queue.async {
            guard self.sessionStarted, !self.finished, self.writer.status == .writing,
                  let input = self.micInput, input.isReadyForMoreMediaData else { return }
            if !self.micStarted {
                guard self.hasNonZeroAudioSamples(box.buffer) else { return }
                self.micStarted = true
            }
            let writerSource = self.limitedMicrophoneSampleBuffer(box.buffer) ?? box.buffer
            guard let sampleBuffer = self.retimedAudioSampleBuffer(writerSource) else { return }
            input.append(sampleBuffer)
        }
    }

    func finish(completion: @escaping @Sendable (URL?) -> Void) {
        queue.async {
            guard !self.finished, self.writer.status == .writing else {
                self.writeFallbackMovie(completion: completion)
                return
            }
            self.finished = true
            if let endTime = self.endSessionTime() {
                self.writer.endSession(atSourceTime: endTime)
            }
            self.videoInput.markAsFinished()
            self.systemAudioInput?.markAsFinished()
            self.micInput?.markAsFinished()
            let url = self.url
            self.writer.finishWriting {
                if self.writer.status == .completed {
                    completion(url)
                } else {
                    self.writeFallbackMovie(completion: completion)
                }
            }
        }
    }

    private func appendVideoOnQueue(_ sampleBuffer: CMSampleBuffer) {
        if !sessionStarted {
            sessionStarted = true
            writer.startSession(atSourceTime: .zero)
        }
        if videoInput.isReadyForMoreMediaData, videoInput.append(sampleBuffer) {
            hasVideoSample = true
            lastVideoPresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            lastVideoDuration = effectiveDuration(for: sampleBuffer)
        }
    }

    private func activePresentationTime(for sourceTime: CMTime) -> CMTime? {
        let seconds = sourceTime.isValid && sourceTime.isNumeric
            ? CMTimeGetSeconds(sourceTime)
            : (lastObservedSourceSeconds ?? 0)
        guard seconds.isFinite else { return nil }
        lastObservedSourceSeconds = max(lastObservedSourceSeconds ?? seconds, seconds)
        guard let mapped = try? pauseTimeline.presentationTime(forSourceTime: seconds) else { return nil }
        return CMTime(seconds: mapped, preferredTimescale: 600_000)
    }

    private func nextVideoPresentationTime() -> CMTime {
        guard let lastVideoPresentationTime else { return .zero }
        return CMTimeAdd(lastVideoPresentationTime, lastVideoDuration)
    }

    private func monotonicVideoPresentationTime(for sourceTime: CMTime) -> CMTime? {
        guard let normalizedTime = activePresentationTime(for: sourceTime) else { return nil }
        guard let lastVideoPresentationTime else { return normalizedTime }
        return CMTimeCompare(normalizedTime, lastVideoPresentationTime) > 0 ? normalizedTime : nextVideoPresentationTime()
    }

    private func retimedVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let presentationTime = monotonicVideoPresentationTime(
            for: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        ) else { return nil }
        return retimedSampleBuffer(sampleBuffer, presentationTime: presentationTime)
    }

    private func retimedSampleBuffer(_ sampleBuffer: CMSampleBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: effectiveDuration(for: sampleBuffer),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var retimed: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &retimed
        ) == noErr else { return nil }
        return retimed
    }

    /// Retimes an audio buffer by shifting only its presentation timestamps onto
    /// the writer timeline while preserving the capture API's timing layout.
    private func retimedAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        let originalPresentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let newPresentation = activePresentationTime(for: originalPresentation) else { return nil }
        let offset = CMTimeSubtract(newPresentation, originalPresentation)
        guard offset.isValid, offset.isNumeric else { return nil }

        var count: CMItemCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr, count > 0 else {
            return nil
        }
        var timings = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &timings, entriesNeededOut: &count) == noErr else {
            return nil
        }
        for index in timings.indices {
            if timings[index].presentationTimeStamp.isValid {
                timings[index].presentationTimeStamp = CMTimeAdd(timings[index].presentationTimeStamp, offset)
            }
            timings[index].decodeTimeStamp = .invalid
        }

        var retimed: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: timings.count,
            sampleTimingArray: &timings,
            sampleBufferOut: &retimed
        ) == noErr else { return nil }
        return retimed
    }

    private func limitedMicrophoneSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee,
              streamDescription.mFormatID == kAudioFormatLinearPCM,
              streamDescription.mBitsPerChannel == 32,
              streamDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return sampleBuffer }

        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount > 0 else { return sampleBuffer }

        var data = Data(count: byteCount)
        let copyStatus = data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: byteCount, destination: baseAddress)
        }
        guard copyStatus == noErr else { return sampleBuffer }

        let knee: Float = 0.98
        var limited = false
        data.withUnsafeMutableBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Float.self)
            for index in samples.indices {
                let sample = samples[index]
                if !sample.isFinite {
                    samples[index] = 0
                    limited = true
                    continue
                }

                let magnitude = abs(sample)
                if magnitude > knee {
                    let excess = magnitude - knee
                    let softened = knee + (1 - knee) * (excess / (excess + 1))
                    samples[index] = sample < 0 ? -softened : softened
                    limited = true
                }
            }
        }
        guard limited else { return sampleBuffer }

        var limitedBlockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &limitedBlockBuffer
        ) == noErr, let limitedBlockBuffer else { return sampleBuffer }

        let replaceStatus = data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferReplaceDataBytes(with: baseAddress, blockBuffer: limitedBlockBuffer, offsetIntoDestination: 0, dataLength: data.count)
        }
        guard replaceStatus == noErr else { return sampleBuffer }

        var timingCount: CMItemCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &timingCount) == noErr, timingCount > 0 else {
            return sampleBuffer
        }
        var timings = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: timingCount)
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: timingCount, arrayToFill: &timings, entriesNeededOut: &timingCount) == noErr else {
            return sampleBuffer
        }

        var limitedSampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: limitedBlockBuffer,
            formatDescription: formatDescription,
            sampleCount: CMSampleBufferGetNumSamples(sampleBuffer),
            sampleTimingEntryCount: timings.count,
            sampleTimingArray: &timings,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &limitedSampleBuffer
        ) == noErr else { return sampleBuffer }

        return limitedSampleBuffer
    }

    private func hasNonZeroAudioSamples(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return true }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        guard length > 0 else { return false }

        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: length,
                destination: baseAddress
            )
        }
        guard status == noErr else { return true }
        return data.contains { $0 != 0 }
    }

    private func effectiveDuration(for sampleBuffer: CMSampleBuffer) -> CMTime {
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        if duration.isValid, duration.isNumeric, CMTimeCompare(duration, .zero) > 0 {
            return duration
        }
        return recordingSyntheticFrameDuration
    }

    private func endSessionTime() -> CMTime? {
        guard let lastVideoPresentationTime else { return nil }
        let endTime = CMTimeAdd(lastVideoPresentationTime, lastVideoDuration)
        return endTime.isValid && endTime.isNumeric ? endTime : nil
    }

    private func makeSampleBuffer(from image: CGImage, presentationTime: CMTime, duration: CMTime = .invalid) -> CMSampleBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var description: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &description
        ) == noErr, let description else { return nil }

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: description,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }
        return sampleBuffer
    }

    private func makeBlackImage() -> CGImage? {
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func writeFallbackMovie(completion: @escaping @Sendable (URL?) -> Void) {
        try? FileManager.default.removeItem(at: url)
        do {
            let fallbackWriter = try AVAssetWriter(outputURL: url, fileType: profile.avFileType)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = false
            guard fallbackWriter.canAdd(input), let image = makeBlackImage() else {
                completion(nil)
                return
            }
            fallbackWriter.add(input)
            fallbackWriter.startWriting()
            fallbackWriter.startSession(atSourceTime: .zero)
            guard let sampleBuffer = makeSampleBuffer(
                from: image,
                presentationTime: .zero,
                duration: CMTime(value: 1, timescale: 10)
            ), input.append(sampleBuffer) else {
                fallbackWriter.cancelWriting()
                completion(nil)
                return
            }
            fallbackWriter.endSession(atSourceTime: recordingSyntheticFrameDuration)
            input.markAsFinished()
            nonisolated(unsafe) let writerForCompletion = fallbackWriter
            fallbackWriter.finishWriting {
                completion(writerForCompletion.status == .completed ? self.url : nil)
            }
        } catch {
            completion(nil)
        }
    }
}

/// Forwards ScreenCaptureKit video and system-audio buffers to the engine.
private final class RecordingStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let engine: RecordingEngine
    private let overlayFrameProvider: (@MainActor @Sendable () -> CGImage?)?
    private let rawFrameDecorationNeeded: (@MainActor @Sendable () -> Bool)?
    private let rawFrameDecorator: (@MainActor @Sendable (CGImage) -> CGImage?)?
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let stateLock = NSLock()
    private var overlayActive = false
    private var overlayFramePending = false
    private var lastOverlayProbeTime: CMTime?
    private var lastOverlayFrameTime: CMTime?

    private static let overlayFrameInterval = CMTime(value: 1, timescale: 10)
    private static let inactiveOverlayProbeInterval = CMTime(value: 1, timescale: 4)

    init(
        engine: RecordingEngine,
        overlayFrameProvider: (@MainActor @Sendable () -> CGImage?)?,
        rawFrameDecorationNeeded: (@MainActor @Sendable () -> Bool)? = nil,
        rawFrameDecorator: (@MainActor @Sendable (CGImage) -> CGImage?)? = nil
    ) {
        self.engine = engine
        self.overlayFrameProvider = overlayFrameProvider
        self.rawFrameDecorationNeeded = rawFrameDecorationNeeded
        self.rawFrameDecorator = rawFrameDecorator
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch type {
        case .screen:
            // Skip frames that aren't complete (e.g. idle/blank) so only real
            // updates are encoded.
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let statusRaw = attachments.first?[.status] as? Int,
                  statusRaw == SCFrameStatus.complete.rawValue else { return }
            let box = SampleBufferBox(buffer: sampleBuffer)
            guard overlayFrameProvider != nil || rawFrameDecorator != nil else {
                engine.appendVideo(box)
                return
            }
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            handleScreenFrame(box, presentationTime: presentationTime)
        case .audio:
            engine.appendSystemAudio(SampleBufferBox(buffer: sampleBuffer))
        default:
            // Microphone audio (ScreenCaptureKit, macOS 15+) shares the video
            // clock, so it aligns with the writer session.
            if #available(macOS 15.0, *), type == .microphone {
                engine.appendMicrophone(SampleBufferBox(buffer: sampleBuffer))
            }
        }
    }

    private func handleScreenFrame(
        _ box: SampleBufferBox,
        presentationTime: CMTime
    ) {
        stateLock.lock()
        let isOverlayActive = overlayActive

        if !isOverlayActive {
            let shouldProbe = !overlayFramePending && shouldProbeInactiveOverlay(at: presentationTime)
            if shouldProbe {
                overlayFramePending = true
                lastOverlayProbeTime = presentationTime
            }
            stateLock.unlock()

            if shouldProbe {
                Task { @MainActor in
                    let image = self.resolvedImage(fallback: box)
                    self.finishOverlayFrame(image: image, fallback: box, presentationTime: presentationTime)
                }
            } else {
                engine.appendVideo(box)
            }
            return
        }

        if overlayFramePending || shouldSkipOverlayFrame(at: presentationTime) {
            stateLock.unlock()
            return
        }

        overlayFramePending = true
        stateLock.unlock()

        Task { @MainActor in
            let image = self.resolvedImage(fallback: box)
            self.finishOverlayFrame(image: image, fallback: box, presentationTime: presentationTime)
        }
    }

    @MainActor
    private func resolvedImage(fallback: SampleBufferBox) -> CGImage? {
        if let image = overlayFrameProvider?() {
            return image
        }
        guard rawFrameDecorationNeeded?() == true,
              let rawFrameDecorator,
              let imageBuffer = CMSampleBufferGetImageBuffer(fallback.buffer) else { return nil }
        let source = CIImage(cvImageBuffer: imageBuffer)
        guard let image = imageContext.createCGImage(source, from: source.extent) else { return nil }
        return rawFrameDecorator(image)
    }

    private func shouldProbeInactiveOverlay(at presentationTime: CMTime) -> Bool {
        guard let lastOverlayProbeTime else { return true }
        return CMTimeCompare(CMTimeSubtract(presentationTime, lastOverlayProbeTime), Self.inactiveOverlayProbeInterval) >= 0
    }

    private func shouldSkipOverlayFrame(at presentationTime: CMTime) -> Bool {
        guard let lastOverlayFrameTime else { return false }
        return CMTimeCompare(CMTimeSubtract(presentationTime, lastOverlayFrameTime), Self.overlayFrameInterval) < 0
    }

    private func finishOverlayFrame(image: CGImage?, fallback: SampleBufferBox, presentationTime: CMTime) {
        if let image {
            engine.appendVideoImage(RecordingImageFrame(image: image, presentationTime: presentationTime))
        } else {
            engine.appendVideo(fallback)
        }

        stateLock.lock()
        overlayActive = image != nil
        overlayFramePending = false
        if image != nil {
            lastOverlayFrameTime = presentationTime
        }
        stateLock.unlock()
    }

    func waitForPendingOverlayFrame() async {
        guard overlayFrameProvider != nil || rawFrameDecorator != nil else { return }
        for _ in 0..<60 {
            if !hasPendingOverlayFrame() { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    func appendFinalOverlayFrameIfNeeded(presentationTime: CMTime) {
        guard let overlayFrameProvider, let image = overlayFrameProvider() else { return }
        engine.appendVideoImageIfNeeded(RecordingImageFrame(image: image, presentationTime: presentationTime))
    }

    func notifyOverlayPresentationStarted() {
        stateLock.lock()
        overlayActive = true
        lastOverlayFrameTime = nil
        stateLock.unlock()
    }

    private func hasPendingOverlayFrame() -> Bool {
        stateLock.lock()
        let pending = overlayFramePending
        stateLock.unlock()
        return pending
    }
}

/// Forwards microphone buffers to the engine.
private final class RecordingMicOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let engine: RecordingEngine

    init(engine: RecordingEngine) {
        self.engine = engine
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        engine.appendMicrophone(SampleBufferBox(buffer: sampleBuffer))
    }
}

/// Draws an orange border around the area being recorded (the whole view, or a
/// selected region). It lives in a click-through window excluded from capture so
/// it never appears in the recording.
@MainActor
private final class RecordingBorderView: NSView {
    /// The region being recorded in view points (top-left origin), or nil for
    /// the whole screen.
    var region: CGRect?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let lineWidth: CGFloat = 6
        // Inset by half the line width so the full stroke stays on screen.
        let rect = (region ?? bounds).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        context.setStrokeColor(NSColor.systemOrange.cgColor)
        context.setLineWidth(lineWidth)
        context.stroke(rect)
    }
}

/// Records the screen (or a selected region) to a movie using ScreenCaptureKit
/// for video and optional system audio, plus an optional microphone via
/// AVCaptureSession, mirroring ZoomIt's recording feature.
@MainActor
final class RecordingController {
    private let captureService: ScreenCaptureService
    private let displayManager: DisplayManager
    private let permissionService: PermissionService
    private let settingsStore: SettingsStore
    private let permissionRelaunchCoordinator: PermissionRelaunchCoordinator?
    private let screenRecordingPermissionSession: ScreenRecordingPermissionSession
    private let preflightProvider: RecordingPreflightProviding
    private let preflightWindowController: RecordingPreflightWindowController
    private let recoverySession: RecordingRecoverySession
    private let movieProfile = RecordingOutputStrategy.defaultMovieProfile

    private(set) var isRecording = false
    private(set) var isPaused = false
    private var isStartingRecording = false
    private var isStoppingRecording = false
    private var isFinalizingRecording = false
    private var onStateChange: ((Bool) -> Void)?
    /// Called right before the Save dialog is shown so any obscuring overlay
    /// (e.g. a zoom overlay at `.screenSaver` level) can be dismissed first.
    var onWillShowSaveDialog: (() -> Void)?

    private var stream: SCStream?
    private var streamOutput: RecordingStreamOutput?
    private var micOutput: RecordingMicOutput?
    private var captureSession: AVCaptureSession?
    private var engine: RecordingEngine?
    private var borderWindow: NSWindow?
    private var recordingDisplay: DisplayDescriptor?
    private var recordingSourceRect: CGRect?
    private let webcam: WebcamOverlayController
    private let inputOverlay = RecordingInputOverlayController()
    private let sampleQueue = DispatchQueue(label: "com.zoomitmac.recorder.samples")
    private var clipEditor: VideoClipEditorController?
    private var recordingResult: RecordingResultController?
    var overlayFrameProvider: (@MainActor @Sendable (CGRect?) -> CGImage?)?

    init(
        captureService: ScreenCaptureService,
        displayManager: DisplayManager,
        permissionService: PermissionService,
        settingsStore: SettingsStore,
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil,
        screenRecordingPermissionSession: ScreenRecordingPermissionSession = ScreenRecordingPermissionSession(),
        preflightProvider: RecordingPreflightProviding,
        preflightWindowController: RecordingPreflightWindowController,
        recoveryStore: RecordingRecoveryStoring
    ) {
        self.captureService = captureService
        self.displayManager = displayManager
        self.permissionService = permissionService
        self.settingsStore = settingsStore
        self.permissionRelaunchCoordinator = permissionRelaunchCoordinator
        self.screenRecordingPermissionSession = screenRecordingPermissionSession
        self.preflightProvider = preflightProvider
        self.preflightWindowController = preflightWindowController
        self.recoverySession = RecordingRecoverySession(store: recoveryStore)
        self.webcam = WebcamOverlayController(permissionService: permissionService)
    }

    /// Toggles recording. When starting, `region` chooses whole-screen vs. a
    /// dragged region. `onStateChange(true/false)` reports start/stop.
    func toggle(region: Bool, onStateChange: @escaping (Bool) -> Void) {
        if isStoppingRecording || isFinalizingRecording || isStartingRecording
            || clipEditor != nil || recordingResult != nil {
            NSSound.beep()
        } else if isRecording {
            stop()
        } else {
            self.onStateChange = onStateChange
            start(region: region)
        }
    }

    var webcamWindowNumberForScreenCaptureExclusion: Int? {
        webcam.windowNumber
    }

    @discardableResult
    func togglePause() -> RecordingPauseCommandEffect {
        let state: RecordingRuntimeState
        if isFinalizingRecording || isStoppingRecording {
            state = .finalizing
        } else if isStartingRecording {
            state = .preparing
        } else if isPaused {
            state = .paused
        } else {
            state = .recording
        }

        let effect = RecordingPauseCommandPolicy.effect(state: state)
        switch effect {
        case .pause where isRecording:
            do {
                try recoverySession.setPhase(.paused)
            } catch {
                presentError(error)
                return .reject
            }
            isPaused = true
            engine?.setPaused(true)
        case .resume where isRecording:
            do {
                try recoverySession.setPhase(.recording)
            } catch {
                presentError(error)
                return .reject
            }
            isPaused = false
            engine?.setPaused(false)
        case .pause, .resume, .reject:
            NSSound.beep()
            return .reject
        }
        return effect
    }

    private func start(region: Bool) {
        guard ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionRelaunchCoordinator: permissionRelaunchCoordinator,
            permissionSession: screenRecordingPermissionSession
        ) else {
            return
        }
        guard let display = displayManager.activeDisplay() else {
            NSSound.beep()
            return
        }

        isStartingRecording = true

        if region {
            selectRegion(on: display) { [weak self] rect in
                guard let self else { return }
                guard let rect else {
                    self.isStartingRecording = false
                    return
                }
                self.beginCapture(display: display, target: .region(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: rect.height
                ))
            }
        } else {
            beginCapture(display: display, target: .fullScreen(displayID: display.id))
        }
    }

    private func beginCapture(display: DisplayDescriptor, target: RecordingTarget) {
        let plan: RecordingCaptureRequestPlan
        do {
            plan = try RecordingCaptureRequestPlanner.plan(target: target, displays: [display], windows: [])
        } catch {
            isStartingRecording = false
            presentError(error)
            return
        }

        let settings = settingsStore.load()
        let targetName = switch target {
        case .fullScreen: "显示器"
        case .region: "选定区域"
        case .window: "选定窗口"
        }
        let preflight = RecordingPreflightPlanner.plan(preflightProvider.input(
            targetName: targetName,
            targetAvailable: true,
            settings: settings
        ))
        preflightWindowController.present(
            preflight,
            audioSelection: RecordingPreflightAudioSelection(settings: settings),
            onProceed: { [weak self] audioSelection in
                self?.beginCaptureAfterPreflight(
                    display: display,
                    plan: plan,
                    audioSelection: audioSelection
                )
            },
            onCancel: { [weak self] in
                self?.isStartingRecording = false
                self?.onStateChange?(false)
            }
        )
    }

    private func beginCaptureAfterPreflight(
        display: DisplayDescriptor,
        plan: RecordingCaptureRequestPlan,
        audioSelection: RecordingPreflightAudioSelection
    ) {
        var settings = settingsStore.load()
        audioSelection.apply(to: &settings)
        settingsStore.save(settings)

        if audioSelection.microphone {
            switch permissionService.microphoneStatus() {
            case .granted:
                break
            case .notDetermined:
                permissionService.requestMicrophoneAccess { [weak self] in
                    guard let self else { return }
                    if self.permissionService.microphoneStatus() == .granted {
                        self.beginCaptureAfterAudioPermission(display: display, plan: plan)
                    } else {
                        self.isStartingRecording = false
                        self.onStateChange?(false)
                    }
                }
                return
            case .denied:
                isStartingRecording = false
                onStateChange?(false)
                permissionService.openMicrophoneSettings()
                return
            }
        }

        beginCaptureAfterAudioPermission(display: display, plan: plan)
    }

    private func beginCaptureAfterAudioPermission(
        display: DisplayDescriptor,
        plan: RecordingCaptureRequestPlan
    ) {
        let sourceRect = plan.sourceRect
        recordingDisplay = display
        recordingSourceRect = sourceRect
        // Show the orange recording border first so it's part of our own windows
        // (excluded from capture) before the stream filter is built.
        showBorder(display: display, region: sourceRect)
        // Show the webcam picture-in-picture overlay (if enabled), positioned
        // inside the recorded area so it appears within the recording. When a
        // ZoomIt overlay is active, the webcam stays visually fixed and is
        // composited into overlay frames instead of being captured as screen
        // content.
        Task { @MainActor in
            do {
                await self.webcam.start(settings: self.settingsStore.load(), area: self.recordedArea(display: display, region: sourceRect))
                try await self.startStreaming(display: display, plan: plan)
                self.isStartingRecording = false
                self.isRecording = true
                self.isPaused = false
                self.onStateChange?(true)
            } catch {
                self.isStartingRecording = false
                self.cleanup()
                self.presentError(error)
                self.onStateChange?(false)
            }
        }
    }

    /// Shows a click-through orange border around the recorded area. The window
    /// is marked non-shareable so it never appears in the recording.
    private func showBorder(display: DisplayDescriptor, region: CGRect?) {
        let window = NSWindow(
            contentRect: display.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Sit above the zoom/draw overlay (also at `.screenSaver`) so the border
        // stays visible while zoomed and drawing. It's click-through and
        // non-shareable, so it neither blocks input nor appears in the recording.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false

        let view = RecordingBorderView(frame: CGRect(origin: .zero, size: display.frame.size))
        view.region = region
        window.contentView = view
        window.orderFrontRegardless()
        self.borderWindow = window
    }

    private func hideBorder() {
        borderWindow?.orderOut(nil)
        borderWindow = nil
    }

    /// The recorded area in global (bottom-left origin) screen coordinates: the
    /// region for a region recording, or the whole display otherwise. `region`
    /// is in display points with a top-left origin, so its Y is flipped.
    private func recordedArea(display: DisplayDescriptor, region: CGRect?) -> CGRect {
        guard let region else { return display.frame }
        return CGRect(
            x: display.frame.minX + region.minX,
            y: display.frame.minY + display.frame.height - region.maxY,
            width: region.width,
            height: region.height
        )
    }

    private func startStreaming(display: DisplayDescriptor, plan: RecordingCaptureRequestPlan) async throws {
        let settings = settingsStore.load()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Capture the whole display, including ZoomIt's own zoom/draw overlays
        // so annotations made while recording are captured. The orange border
        // is kept out of the recording via its window's `sharingType = .none`.
        let filter: SCContentFilter
        switch plan.filter {
        case .display(let displayID, let excludingWindowIDs):
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                throw ScreenCaptureError.displayNotFound
            }
            let excludedWindows = content.windows.filter { excludingWindowIDs.contains($0.windowID) }
            filter = SCContentFilter(display: scDisplay, excludingWindows: excludedWindows)
        case .window(let windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw RecordingCaptureRequestPlanError.windowNotFound(windowID)
            }
            filter = SCContentFilter(desktopIndependentWindow: window)
        }

        let configuration = SCStreamConfiguration()
        let sourceRect = plan.sourceRect
        if let sourceRect {
            configuration.sourceRect = sourceRect
        }
        configuration.width = plan.pixelWidth
        configuration.height = plan.pixelHeight
        configuration.showsCursor = plan.showsCursor
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.sampleRate = movieProfile.audioSampleRate
        configuration.channelCount = movieProfile.audioChannelCount
        let overlayFrameProvider = self.overlayFrameProvider
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: overlayFrameProvider == nil ? 60 : 30)
        configuration.queueDepth = 5

        let wantsSystemAudio = settings.recordSystemAudio
        if wantsSystemAudio {
            configuration.capturesAudio = true
        }
        // Only attempt the microphone when already authorized; requesting access
        // without a bundled usage description would crash the bare executable.
        let wantsMic = settings.recordMicrophone
            && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(RecordingFileNaming.temporaryMovieFilename(profile: movieProfile))
        try recoverySession.start(temporaryURL: url)
        let engine = try RecordingEngine(
            url: url,
            width: plan.pixelWidth,
            height: plan.pixelHeight,
            systemAudio: wantsSystemAudio,
            microphone: wantsMic,
            profile: movieProfile
        )
        await engine.startWriting()
        self.engine = engine

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        let output = RecordingStreamOutput(
            engine: engine,
            overlayFrameProvider: overlayFrameProvider.map { provider in
                { @MainActor @Sendable in
                guard let overlayImage = provider(sourceRect) else { return nil }
                let composedImage: CGImage
                if let webcamFrame = self.webcam.recordingSnapshot() {
                    composedImage = self.composite(
                        webcamFrame,
                        over: overlayImage,
                        display: display,
                        sourceRect: sourceRect
                    )
                } else {
                    composedImage = overlayImage
                }
                return self.inputOverlay.compositeIfActive(over: composedImage) ?? composedImage
                }
            },
            rawFrameDecorationNeeded: { @MainActor @Sendable in
                self.inputOverlay.hasActivePresentation()
            },
            rawFrameDecorator: { @MainActor @Sendable image in
                self.inputOverlay.compositeIfActive(over: image)
            }
        )
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleQueue)
        if wantsSystemAudio {
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: sampleQueue)
        }
        self.streamOutput = output
        self.stream = stream
        inputOverlay.onPresentationStarted = { [weak output] in
            output?.notifyOverlayPresentationStarted()
        }
        inputOverlay.start(
            settings: settings,
            recordingArea: recordedArea(display: display, region: sourceRect)
        )

        if wantsMic, let device = AudioDevices.microphone(forID: settings.microphoneDeviceID) {
            try? setupMicrophone(device: device, engine: engine, windNoiseRemoval: settings.recordNoiseCancellation)
        }

        try await stream.startCapture()
    }

    private func composite(_ webcamFrame: WebcamRecordingFrame, over overlayImage: CGImage, display: DisplayDescriptor, sourceRect: CGRect?) -> CGImage {
        let width = overlayImage.width
        let height = overlayImage.height
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return overlayImage }

        context.interpolationQuality = .high
        context.draw(overlayImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scale = CGFloat(width) / (sourceRect?.width ?? display.frame.width)
        let source = sourceRect ?? CGRect(origin: .zero, size: display.frame.size)
        let frame = webcamFrame.frame
        let x = (frame.minX - display.frame.minX - source.minX) * scale
        let topY = (display.frame.maxY - frame.maxY - source.minY) * scale
        let webcamWidth = frame.width * scale
        let webcamHeight = frame.height * scale
        let drawRect = CGRect(x: x, y: CGFloat(height) - topY - webcamHeight, width: webcamWidth, height: webcamHeight).integral
        guard drawRect.intersects(CGRect(x: 0, y: 0, width: width, height: height)) else { return overlayImage }

        context.saveGState()
        let clipped = drawRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        let path = CGPath(roundedRect: clipped, cornerWidth: webcamFrame.cornerRadius * scale, cornerHeight: webcamFrame.cornerRadius * scale, transform: nil)
        context.addPath(path)
        context.clip()

        let imageSize = CGSize(width: webcamFrame.image.width, height: webcamFrame.image.height)
        let imageAspect = imageSize.width / imageSize.height
        let rectAspect = drawRect.width / drawRect.height
        var imageRect = drawRect
        if imageAspect > rectAspect {
            imageRect.size.width = drawRect.height * imageAspect
            imageRect.origin.x = drawRect.midX - imageRect.width / 2
        } else {
            imageRect.size.height = drawRect.width / imageAspect
            imageRect.origin.y = drawRect.midY - imageRect.height / 2
        }
        context.draw(webcamFrame.image, in: imageRect)
        context.restoreGState()

        return context.makeImage() ?? overlayImage
    }

    private func setupMicrophone(device: AVCaptureDevice, engine: RecordingEngine, windNoiseRemoval: Bool) throws {
        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        if windNoiseRemoval {
            _ = AudioDevices.setWindNoiseRemoval(true, on: input)
        }
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureAudioDataOutput()
        let micOut = RecordingMicOutput(engine: engine)
        output.setSampleBufferDelegate(micOut, queue: sampleQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.startRunning()
        self.captureSession = session
        self.micOutput = micOut
    }

    private func stop() {
        guard isRecording, !isStoppingRecording else { return }
        isStoppingRecording = true
        isFinalizingRecording = true
        try? recoverySession.setPhase(.finalizing)
        isPaused = false
        engine?.setPaused(false)
        hideBorder()

        captureSession?.stopRunning()
        captureSession = nil
        micOutput = nil

        let engine = self.engine
        let stream = self.stream
        let streamOutput = self.streamOutput
        let recordingDisplay = self.recordingDisplay
        let recordingSourceRect = self.recordingSourceRect
        self.stream = nil
        self.streamOutput = nil
        self.recordingDisplay = nil
        self.recordingSourceRect = nil

        Task { @MainActor in
            try? await stream?.stopCapture()
            await streamOutput?.waitForPendingOverlayFrame()
            streamOutput?.appendFinalOverlayFrameIfNeeded(presentationTime: CMClockGetTime(CMClockGetHostTimeClock()))
            if let recordingDisplay,
               let image = try? await self.captureFallbackFrame(display: recordingDisplay, sourceRect: recordingSourceRect) {
                let composedImage = self.inputOverlay.compositeIfActive(over: image) ?? image
                engine?.appendVideoImageAtEnd(RecordingImageFrame(image: composedImage, presentationTime: CMClockGetTime(CMClockGetHostTimeClock())))
            }
            engine?.appendBlackVideoFrameIfNeeded(presentationTime: CMClockGetTime(CMClockGetHostTimeClock()))
            self.webcam.stop()
            self.inputOverlay.stop()
            await engine?.waitForQueuedAppends()
            engine?.finish { url in
                Task { @MainActor in
                    self.engine = nil
                    self.isRecording = false
                    self.isPaused = false
                    self.isStoppingRecording = false
                    self.onStateChange?(false)
                    if let url {
                        try? self.recoverySession.setPhase(.finalized)
                        self.presentSave(tempURL: url)
                    } else {
                        self.isFinalizingRecording = false
                        self.presentError(ScreenCaptureError.recordingFailed)
                    }
                }
            }
        }
    }

    private func captureFallbackFrame(display: DisplayDescriptor, sourceRect: CGRect?) async throws -> CGImage {
        let frame = try await captureService.captureDisplay(display)
        guard let sourceRect else { return frame.image }
        let scale = display.scaleFactor
        let pixelRect = CGRect(
            x: sourceRect.minX * scale,
            y: sourceRect.minY * scale,
            width: sourceRect.width * scale,
            height: sourceRect.height * scale
        ).integral
        return frame.image.cropping(to: pixelRect) ?? frame.image
    }

    private func presentSave(tempURL: URL) {
        // Dismiss any zoom overlay first so the editor isn't hidden behind it.
        onWillShowSaveDialog?()
        DispatchQueue.main.async { [weak self] in
            self?.presentResultPage(tempURL: tempURL)
        }
    }

    private func presentResultPage(tempURL: URL) {
        let result = RecordingResultController()
        recordingResult = result
        result.present(
            tempURL: tempURL,
            suggestedName: suggestedFilename(),
            outputProfile: movieProfile,
            onExport: { [weak self] editedURL in
            guard let self else { return }
            self.recordingResult = nil
            var retainedRecoveryURL: URL?
            if editedURL != tempURL {
                do {
                    try self.recoverySession.replaceTemporaryURL(editedURL)
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    retainedRecoveryURL = tempURL
                }
            }
            self.savePanel(for: editedURL, retainedRecoveryURL: retainedRecoveryURL)
        }, onCancel: { [weak self] in
            self?.recordingResult = nil
            self?.isFinalizingRecording = false
            try? FileManager.default.removeItem(at: tempURL)
            try? self?.recoverySession.clearAfterSuccessfulDisposition()
        })
    }

    private func savePanel(for tempURL: URL, retainedRecoveryURL: URL? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename()
        panel.allowedContentTypes = [movieProfile.saveContentType]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)

        if panel.runModal() == .OK, let destination = panel.url {
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.moveItem(at: tempURL, to: destination)
                if let retainedRecoveryURL {
                    try? FileManager.default.removeItem(at: retainedRecoveryURL)
                }
                try? recoverySession.clearAfterSuccessfulDisposition()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        } else {
            try? FileManager.default.removeItem(at: tempURL)
            if let retainedRecoveryURL {
                try? FileManager.default.removeItem(at: retainedRecoveryURL)
            }
            try? recoverySession.clearAfterSuccessfulDisposition()
        }
        isFinalizingRecording = false
    }

    private func suggestedFilename() -> String {
        RecordingFileNaming.suggestedMovieFilename(date: Date(), profile: movieProfile)
    }

    /// Opens an existing video file in the clip editor (trim, append, save),
    /// mirroring ZoomIt's standalone "Trim" workflow. The edited result is
    /// exported and the user picks where to save it.
    func openForTrim() {
        let open = NSOpenPanel()
        open.title = "Trim Video"
        open.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard open.runModal() == .OK, let url = open.url else { return }
        let editor = VideoClipEditorController()
        self.clipEditor = editor
        editor.present(
            tempURL: url,
            suggestedName: suggestedFilename(),
            mode: .advanced,
            onSave: { [weak self] editedURL in
            self?.clipEditor = nil
            self?.saveTrimmedClip(editedURL: editedURL, originalURL: url)
        }, onCancel: { [weak self] in
            self?.clipEditor = nil
        })
    }

    /// Action for saving a clip opened from an existing file (the Trim
    /// workflow). If the editor exported a new temp file, that temp is moved
    /// into place; if it returned the user's own original (no edits), the
    /// original is copied so it is preserved — matching Windows ZoomIt, which
    /// never deletes the source file.
    enum TrimSaveAction: Equatable { case move, copy }

    static func trimSaveAction(editedURL: URL, originalURL: URL) -> TrimSaveAction {
        editedURL == originalURL ? .copy : .move
    }

    /// Saves a clip that was opened from an existing file, always preserving the
    /// user's original source file.
    private func saveTrimmedClip(editedURL: URL, originalURL: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename()
        panel.allowedContentTypes = [movieProfile.saveContentType]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)

        let action = Self.trimSaveAction(editedURL: editedURL, originalURL: originalURL)
        if panel.runModal() == .OK, let destination = panel.url {
            if destination != originalURL {
                try? FileManager.default.removeItem(at: destination)
            }
            do {
                switch action {
                case .move:
                    // Move the exported temp file into place; original untouched.
                    if destination != editedURL {
                        try FileManager.default.moveItem(at: editedURL, to: destination)
                    }
                case .copy:
                    // No edits: copy the user's original, preserving the source.
                    if destination != editedURL {
                        try FileManager.default.copyItem(at: editedURL, to: destination)
                    }
                }
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        } else if action == .move {
            // Discard the temp export; never delete the user's original file.
            try? FileManager.default.removeItem(at: editedURL)
        }
    }

    private func selectRegion(on display: DisplayDescriptor, completion: @escaping (CGRect?) -> Void) {
        Task { @MainActor in
            do {
                let frame = try await captureService.captureDisplay(display)
                let window = SnipWindow(
                    contentRect: frame.display.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.level = .screenSaver
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                window.backgroundColor = .clear
                window.isOpaque = false
                window.isReleasedWhenClosed = false

                let view = SnipSelectionView(
                    frame: CGRect(origin: .zero, size: frame.display.frame.size),
                    image: frame.image
                )
                var holder: NSWindow? = window
                var cursorLease: CrosshairCursorLease?
                view.onComplete = { rect in
                    cursorLease?.invalidate()
                    cursorLease = nil
                    holder?.orderOut(nil)
                    holder = nil
                    completion(rect)
                }
                window.contentView = view
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                window.makeFirstResponder(view)
                cursorLease = CrosshairCursorLease(window: window, purpose: .recordingSelection)
                cursorLease?.activate()
            } catch {
                completion(nil)
            }
        }
    }

    private func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        micOutput = nil
        stream = nil
        streamOutput = nil
        engine = nil
        recordingDisplay = nil
        recordingSourceRect = nil
        isFinalizingRecording = false
        isStartingRecording = false
        isStoppingRecording = false
        hideBorder()
        webcam.stop()
        inputOverlay.stop()
        isRecording = false
        isPaused = false
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
