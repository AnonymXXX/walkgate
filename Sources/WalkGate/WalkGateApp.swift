import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}

@main
struct WalkGateApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var session = SessionController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(session: session)
    } label: {
      Label(session.menuBarTitle, systemImage: "figure.walk.motion")
        .accessibilityLabel("WalkGate，剩余 \(session.menuBarTitle)")
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView(session: session)
    }
  }
}
