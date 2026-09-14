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

struct TransparentPanelWindowConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = WindowConfigurationView()
    view.configureWindow()
    return view
  }

  func updateNSView(_ view: NSView, context: Context) {
    (view as? WindowConfigurationView)?.configureWindow()
  }
}

private final class WindowConfigurationView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    configureWindow()
  }

  func configureWindow() {
    DispatchQueue.main.async { [weak self] in
      guard let window = self?.window else { return }
      window.isOpaque = false
      window.backgroundColor = .clear
      window.contentView?.wantsLayer = true
      window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
  }
}

struct ClearWindowContainerBackground: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(macOS 15.0, *) {
      content.containerBackground(.clear, for: .window)
    } else {
      content
    }
  }
}
