import AppKit
import SwiftUI

@MainActor
final class BreakOverlayCoordinator {
  private weak var session: SessionController?
  private var windows: [NSWindow] = []
  private var isVisible = false
  private var screenObserver: NSObjectProtocol?
  private var previousPresentationOptions: NSApplication.PresentationOptions?
  private var previousApplication: NSRunningApplication?

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
    previousApplication = NSWorkspace.shared.frontmostApplication
    previousPresentationOptions = NSApp.presentationOptions
    isVisible = true
    NSApp.activate(ignoringOtherApps: true)
    // Preserve the visible Dock/menu bar so visibleFrame excludes their occupied space.
    NSApp.presentationOptions = [.disableProcessSwitching]
    rebuildWindows()
  }

  func hide() {
    isVisible = false
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    if let previousPresentationOptions {
      NSApp.presentationOptions = previousPresentationOptions
    }
    previousPresentationOptions = nil
    previousApplication?.activate(options: [])
    previousApplication = nil
  }

  private func rebuildWindows() {
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    guard let session else { return }

    // Keep the desktop visible, but consume clicks on every display during a break.
    // No global event tap: system emergency controls remain available.
    for screen in NSScreen.screens {
      let shield = OverlayWindow(
        contentRect: screen.frame, styleMask: [.borderless],
        backing: .buffered, defer: false, screen: screen)
      shield.setFrame(screen.frame, display: true)
      shield.level = .screenSaver
      shield.backgroundColor = NSColor.black.withAlphaComponent(0.015)
      shield.isOpaque = false
      shield.hasShadow = false
      shield.hidesOnDeactivate = false
      shield.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      shield.contentView = InputShieldView()
      shield.orderFrontRegardless()
      windows.append(shield)
    }

    if let screen = NSScreen.screens.first(where: {
      NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
    }) ?? NSScreen.main {
      let area = screen.visibleFrame
      // Anchor above the Dock, rather than against the physical screen bottom.
      let frame = NSRect(x: area.maxX - 320, y: area.minY + 20, width: 300, height: 210)
      let window = OverlayWindow(
        contentRect: frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.setFrame(frame, display: true)
      window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
      window.backgroundColor = .clear
      window.isOpaque = false
      window.hasShadow = true
      window.hidesOnDeactivate = false
      window.acceptsMouseMovedEvents = true
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window.contentView = NSHostingView(rootView: BreakOverlayView(session: session))
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
  }
}

private final class InputShieldView: NSView {
  override var acceptsFirstResponder: Bool { true }
  override func mouseDown(with event: NSEvent) {}
  override func rightMouseDown(with event: NSEvent) {}
  override func otherMouseDown(with event: NSEvent) {}
  override func scrollWheel(with event: NSEvent) {}
  override func keyDown(with event: NSEvent) {}
}

private final class OverlayWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
