import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let session: SessionController
  private var window: NSWindow?
  private var hasPositionedWindow = false

  init(session: SessionController) {
    self.session = session
    super.init()
  }

  func show() {
    NSApp.setActivationPolicy(.regular)
    let window = window ?? makeWindow()
    self.window = window
    if !hasPositionedWindow {
      window.center()
      hasPositionedWindow = true
    }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 590),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "WalkGate设置"
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentViewController = NSHostingController(rootView: SettingsView(session: session))
    window.setContentSize(NSSize(width: 440, height: 590))
    return window
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    session.releaseFrontmostStatusIfNeeded()
  }
}
