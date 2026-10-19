import SwiftUI
import ServiceManagement
import ApplicationServices

/// Settings: launch at login, fallback notifications, Accessibility status and the support button.
struct SettingsView: View {
    @AppStorage(Notifier.enabledKey) private var notifyOnFallback = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var trusted = AXIsProcessTrusted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Notify when a named display is not connected", isOn: $notifyOnFallback)
                    .onChange(of: notifyOnFallback) { _, enabled in if enabled { Notifier.requestPermission() } }
            }
            Section("Permissions") {
                HStack(alignment: .top) {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                        Text(trusted ? "Granted — windows can be moved."
                             : "Required to move windows. Enable WindowThrowKeys in System Settings › Privacy & Security › Accessibility.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !trusted {
                        Button("Grant Access…") { WindowMover.requestAccess() }
                    }
                }
            }
            Section {
                HStack {
                    Text("WindowThrowKeys is free and open source.")
                    Spacer()
                    Button("Support / Donate ❤️") { openDonationPage() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(timer) { _ in trusted = AXIsProcessTrusted() }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let isEnabled = SMAppService.mainApp.status == .enabled
        guard enabled != isEnabled else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = isEnabled
        }
    }
}
