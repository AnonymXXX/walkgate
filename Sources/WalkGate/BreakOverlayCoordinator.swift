import AppKit
import SwiftUI

@MainActor
final class BreakOverlayCoordinator {
  private weak var session: SessionController?
  private var windows: [NSWindow] = []
  private var isVisible = false
  private var screenObserver: NSObjectProtocol?

  init(session: SessionController) {
    self.session = session
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard self?.isVisible == true else { return }
        self?.rebuildWindows()
      }
    }
  }

  deinit {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
  }

  func show() {
    guard !isVisible else { return }
    isVisible = true
    rebuildWindows()
    NSApp.activate(ignoringOtherApps: true)
  }

  func hide() {
    isVisible = false
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
  }

  private func rebuildWindows() {
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    guard let session else { return }

    for screen in NSScreen.screens {
      let window = OverlayWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.setFrame(screen.frame, display: true)
      window.level = .screenSaver
      window.backgroundColor = .clear
      window.isOpaque = false
      window.hasShadow = false
      window.acceptsMouseMovedEvents = true
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window.contentView = NSHostingView(rootView: BreakOverlayView(session: session))
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
  }
}

private final class OverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
