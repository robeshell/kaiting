import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate {
  var mainWindow: MainFlutterWindow?
  private var closeToBackground = true

  func attach(mainWindow: MainFlutterWindow) {
    self.mainWindow = mainWindow
    mainWindow.delegate = self
    NSApp.setActivationPolicy(.regular)
  }

  func setCloseToBackground(_ value: Bool) {
    closeToBackground = value
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    NSApp.setActivationPolicy(.regular)
    return true
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      mainWindow?.makeKeyAndOrderFront(nil)
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !closeToBackground
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
