import SwiftUI
import ApplicationServices

/// App entry point: a menu bar extra, the Edit Actions window and the Settings window.
@main
struct WindowThrowKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("WindowThrowKeys", systemImage: "macwindow.on.rectangle") {
            MenuContent()
        }
        Window("Edit Actions", id: "editor") {
            EditorView()
                .frame(minWidth: 700, minHeight: 480)
        }
        Settings {
            SettingsView()
        }
    }
}

/// Starts the window tracker and hotkey registration as soon as the app launches.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = WindowMover.shared
        _ = ActionStore.shared
        if !AXIsProcessTrusted() { WindowMover.requestAccess() }
    }
}

/// Opens the developer's donation page.
func openDonationPage() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}

/// The menu shown from the menu bar icon: every action with its shortcut, plus app commands.
struct MenuContent: View {
    @ObservedObject private var store = ActionStore.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if store.actions.isEmpty {
            Button("Add Starter Actions") { store.addStarters() }
        }
        ForEach(store.actions) { action in
            Button(action.hotkey.map { "\(action.name)\t\($0.display)" } ?? action.name) {
                store.run(action)
            }
        }
        Divider()
        Button("Edit Actions…") {
            openWindow(id: "editor")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        if !AXIsProcessTrusted() {
            Button("Grant Accessibility Access…") { WindowMover.requestAccess() }
        }
        Button("Support / Donate ❤️") { openDonationPage() }
        Divider()
        Button("Quit WindowThrowKeys") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
