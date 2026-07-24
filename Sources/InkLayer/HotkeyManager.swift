import Carbon
import AppKit

/// Carbon RegisterEventHotKey：免辅助功能权限的全局热键
/// 数字热键 + 独立 Esc；带防抖，避免按一次触发两次（key repeat / 系统连发）
final class HotkeyManager {
    private var refs: [EventHotKeyRef] = []
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var lastFire: [UInt32: CFAbsoluteTime] = [:]
    private static var installed = false
    /// 同一热键最短间隔（秒）—— 挡住连发，不挡正常连按
    private static let debounce: CFAbsoluteTime = 0.35

    private enum ID {
        static let escape: UInt32 = 100
    }

    private static let vkForDigit: [Int: UInt32] = [
        0: 29, 1: 18, 2: 19, 3: 20, 4: 21, 5: 23, 6: 22, 7: 26, 8: 28, 9: 25
    ]

    func register(digit: Int, handler: @escaping () -> Void) {
        guard let vk = HotkeyManager.vkForDigit[digit] else { return }
        register(id: UInt32(digit), keyCode: vk, modifiers: UInt32(controlKey), handler: handler)
    }

    func registerEscape(_ handler: @escaping () -> Void) {
        register(id: ID.escape, keyCode: UInt32(kVK_Escape), modifiers: 0, handler: handler)
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32,
                          handler: @escaping () -> Void) {
        HotkeyManager.handlers[id] = handler
        HotkeyManager.installHandlerOnce()
        let hotKeyID = EventHotKeyID(signature: OSType(0x494E4B4C), id: id) // 'INKL'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            Telemetry.shared.log("hotkey.register_failed",
                                 ["id": "\(id)", "status": "\(status)"])
        }
        if let ref { refs.append(ref) }
    }

    private static func installHandlerOnce() {
        guard !installed else { return }
        installed = true
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let now = CFAbsoluteTimeGetCurrent()
            if let prev = HotkeyManager.lastFire[hkID.id],
               now - prev < HotkeyManager.debounce {
                return noErr // 防抖丢弃
            }
            HotkeyManager.lastFire[hkID.id] = now
            HotkeyManager.handlers[hkID.id]?()
            return noErr
        }, 1, &eventSpec, nil, nil)
    }
}
