import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 无 Dock 图标，菜单栏常驻

let delegate = AppDelegate()
app.delegate = delegate

app.run()
