import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let session = SessionController()

  private var statusItemController: StatusItemController?
  private var settingsWindowController: SettingsWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    configureMainMenu()

    let settingsWindowController = SettingsWindowController(session: session)
    self.settingsWindowController = settingsWindowController

    let statusItemController = StatusItemController(session: session) { [weak settingsWindowController] in
      settingsWindowController?.show()
    }
    self.statusItemController = statusItemController
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  private func configureMainMenu() {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem(title: "WalkGate", action: nil, keyEquivalent: "")
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: L("隐藏 WalkGate", "Hide WalkGate"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let hideOthersItem = appMenu.addItem(
      withTitle: L("隐藏其他", "Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h")
    hideOthersItem.keyEquivalentModifierMask = [.command, .option]
    appMenu.addItem(
      withTitle: L("全部显示", "Show All"), action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: L("退出 WalkGate", "Quit WalkGate"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appMenuItem.submenu = appMenu

    let editMenuItem = NSMenuItem(title: L("编辑", "Edit"), action: nil, keyEquivalent: "")
    mainMenu.addItem(editMenuItem)
    let editMenu = NSMenu(title: L("编辑", "Edit"))
    editMenu.addItem(withTitle: L("撤销", "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: L("重做", "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: L("剪切", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: L("拷贝", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: L("粘贴", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: L("全选", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu

    NSApp.mainMenu = mainMenu
  }
}
