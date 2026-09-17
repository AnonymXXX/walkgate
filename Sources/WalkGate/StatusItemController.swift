import AppKit
import Combine
import SwiftUI
import WalkGateCore

@MainActor
final class StatusItemController {
  private let session: SessionController
  private let statusItem: NSStatusItem
  private let panel: MenuPanel
  private let panelHostingController: NSHostingController<MenuBarView>

  private var windowObservers: [NSObjectProtocol] = []
  private var workspaceObservers: [NSObjectProtocol] = []
  private var cancellables: Set<AnyCancellable> = []
  private var localMouseMonitor: Any?
  private var globalMouseMonitor: Any?

  init(session: SessionController, onOpenSettings: @escaping () -> Void) {
    self.session = session

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    self.statusItem = statusItem

    let panel = MenuPanel(
      contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    self.panel = panel

    let hostingController = NSHostingController(
      rootView: MenuBarView(session: session, onOpenSettings: onOpenSettings))
    hostingController.sizingOptions = [.preferredContentSize]
    self.panelHostingController = hostingController

    if let button = statusItem.button {
      button.image = Self.makeStatusImage()
      button.target = self
      button.action = #selector(togglePanel(_:))
      button.sendAction(on: [.leftMouseUp])
    }

    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.becomesKeyOnlyIfNeeded = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentViewController = hostingController

    observeDismissalTriggers()
    updateAccessibilityLabel()
    session.$snapshot.sink { [weak self] _ in
      self?.updateAccessibilityLabel()
    }.store(in: &cancellables)
    session.$workdayState.sink { [weak self] _ in
      self?.updateAccessibilityLabel()
    }.store(in: &cancellables)
  }

  deinit {
    for observer in windowObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    for observer in workspaceObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    if let localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
    }
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
  }

  @objc private func togglePanel(_ sender: Any?) {
    if panel.isVisible {
      hidePanel()
    } else {
      showPanel()
    }
  }

  func showPanel() {
    guard let button = statusItem.button, let buttonWindow = button.window else { return }

    panelHostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = panelHostingController.view.fittingSize
    if fittingSize.width > 0, fittingSize.height > 0 {
      panel.setContentSize(fittingSize)
    }
    positionPanel(below: button, in: buttonWindow)
    panel.makeKeyAndOrderFront(nil)
  }

  func hidePanel() {
    guard panel.isVisible else { return }
    panel.orderOut(nil)
  }

  private func positionPanel(below button: NSStatusBarButton, in buttonWindow: NSWindow) {
    let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    let size = panel.frame.size
    let screen = NSScreen.screens.first { $0.frame.intersects(buttonFrame) } ?? NSScreen.main
    let visibleFrame = screen?.visibleFrame
      ?? NSRect(x: buttonFrame.minX, y: 0, width: size.width, height: size.height)
    panel.setFrameOrigin(
      MenuPanelPositioning.origin(
        anchorFrame: buttonFrame,
        panelSize: size,
        visibleFrame: visibleFrame
      ))
  }

  private func observeDismissalTriggers() {
    let windowCenter = NotificationCenter.default
    windowObservers.append(
      windowCenter.addObserver(
        forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
      ) { [weak self] notification in
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
          guard let self, window !== self.panel else { return }
          self.hidePanel()
        }
      })
    windowObservers.append(
      windowCenter.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.hidePanel()
        }
      })

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceObservers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.handleActiveSpaceChange()
        }
      })
    workspaceObservers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
      ) { [weak self] notification in
        guard
          let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
          application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        Task { @MainActor in
          self?.hidePanel()
        }
      })

    localMouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
      guard let self, self.panel.isVisible else { return event }
      let statusItemWindow = self.statusItem.button?.window
      if event.window !== self.panel, event.window !== statusItemWindow {
        self.hidePanel()
      }
      return event
    }
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      Task { @MainActor in
        self?.hidePanel()
      }
    }
  }

  private func updateAccessibilityLabel() {
    guard let button = statusItem.button else { return }
    button.setAccessibilityLabel("WalkGate，剩余 \(session.menuBarTitle)")
  }

  private func handleActiveSpaceChange() {
    hidePanel()
    statusItem.isVisible = true
    statusItem.button?.image = Self.makeStatusImage()
    statusItem.button?.needsDisplay = true
    updateAccessibilityLabel()
  }

  private static func makeStatusImage() -> NSImage? {
    let image = NSImage(
      systemSymbolName: "figure.walk.motion", accessibilityDescription: "WalkGate")
    image?.isTemplate = true
    return image
  }
}

private final class MenuPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
