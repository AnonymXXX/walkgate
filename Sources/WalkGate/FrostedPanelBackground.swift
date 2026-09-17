import AppKit
import SwiftUI

struct FrostedPanelBackground: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .menu
  var materialOpacity: CGFloat = 0.45

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    configure(view)
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    configure(view)
  }

  private func configure(_ view: NSVisualEffectView) {
    view.material = material
    view.blendingMode = .behindWindow
    view.state = .active
    view.alphaValue = materialOpacity
  }
}

struct MenuPanelVisibilityObserver: NSViewRepresentable {
  let onVisibilityChange: (Bool) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = WindowVisibilityView()
    view.onVisibilityChange = onVisibilityChange
    return view
  }

  func updateNSView(_ view: NSView, context: Context) {
    guard let view = view as? WindowVisibilityView else { return }
    view.onVisibilityChange = onVisibilityChange
    view.reportVisibility()
  }

  static func dismantleNSView(_ view: NSView, coordinator: ()) {
    (view as? WindowVisibilityView)?.stopObserving()
  }
}

private final class WindowVisibilityView: NSView {
  var onVisibilityChange: ((Bool) -> Void)?

  private weak var observedWindow: NSWindow?
  private var observers: [NSObjectProtocol] = []
  private var lastReportedVisibility: Bool?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    observeWindow()
  }

  deinit {
    stopObserving()
  }

  func reportVisibility() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let isVisible = self.window.map(Self.isWindowOnScreen) ?? false
      guard self.lastReportedVisibility != isVisible else { return }
      self.lastReportedVisibility = isVisible
      self.onVisibilityChange?(isVisible)
    }
  }

  func stopObserving() {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
    observedWindow = nil
  }

  private func observeWindow() {
    guard observedWindow !== window else {
      reportVisibility()
      return
    }

    stopObserving()
    guard let window else {
      reportVisibility()
      return
    }
    observedWindow = window

    let names: [Notification.Name] = [
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
      NSWindow.didChangeOcclusionStateNotification,
      NSWindow.willCloseNotification,
    ]
    observers = names.map { name in
      NotificationCenter.default.addObserver(
        forName: name,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.reportVisibility()
      }
    }
    reportVisibility()
  }

  private static func isWindowOnScreen(_ window: NSWindow) -> Bool {
    guard
      let windowInfo = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return false }

    let windowNumber = window.windowNumber
    return windowInfo.contains { info in
      (info[kCGWindowNumber as String] as? Int) == windowNumber
    }
  }
}
