import AppKit
import UniformTypeIdentifiers

/// Owns the list of throw actions: persistence as JSON in Application Support, editing helpers,
/// import/export, and running an action against the front window.
final class ActionStore: ObservableObject {
    static let shared = ActionStore()

    @Published var actions: [ThrowAction] = [] {
        didSet {
            save()
            HotkeyManager.shared.register(actions)
        }
    }

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("WindowThrowKeys", isDirectory: true).appendingPathComponent("actions.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ThrowAction].self, from: data) {
            actions = decoded
        }
        HotkeyManager.shared.register(actions)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(actions).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("WindowThrowKeys: failed to save actions: \(error.localizedDescription)")
        }
    }

    // MARK: Editing

    @discardableResult
    func add(_ action: ThrowAction = ThrowAction(name: "New Action", x: 10, y: 10, width: 80, height: 80)) -> UUID {
        actions.append(action)
        return action.id
    }

    func addStarters() { actions.append(contentsOf: ThrowAction.starters) }

    @discardableResult
    func duplicate(_ id: UUID) -> UUID? {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = actions[index]
        copy.id = UUID()
        copy.name += " Copy"
        copy.hotkey = nil
        actions.insert(copy, at: index + 1)
        return copy.id
    }

    func delete(_ id: UUID) { actions.removeAll { $0.id == id } }

    /// Creates a new action whose rectangle is the current front window's frame.
    func captureNew() -> UUID? {
        do {
            var action = ThrowAction(name: "Captured Window")
            try WindowMover.shared.capture(into: &action)
            return add(action)
        } catch {
            Self.alert(error.localizedDescription)
            return nil
        }
    }

    /// Names of other actions that share this action's hotkey.
    func conflicts(for action: ThrowAction) -> [String] {
        guard let hk = action.hotkey else { return [] }
        return actions.filter { $0.id != action.id && $0.hotkey?.collides(with: hk) == true }.map(\.name)
    }

    // MARK: Running

    func run(id: UUID) {
        if let action = actions.first(where: { $0.id == id }) { run(action) }
    }

    func run(_ action: ThrowAction) {
        do {
            if let missing = try WindowMover.shared.perform(action) {
                Notifier.displayMissing(missing, action: action.name)
            }
        } catch ThrowError.notTrusted {
            WindowMover.requestAccess()
        } catch {
            NSSound.beep()
        }
    }

    // MARK: Import / Export

    func exportActions() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "WindowThrowKeys Actions.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(actions).write(to: url, options: .atomic)
        } catch {
            Self.alert("Could not export actions: \(error.localizedDescription)")
        }
    }

    func importActions() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try JSONDecoder().decode([ThrowAction].self, from: Data(contentsOf: url))
            actions.append(contentsOf: imported.map { var a = $0; a.id = UUID(); return a })
        } catch {
            Self.alert("That file does not contain valid WindowThrowKeys actions.")
        }
    }

    static func alert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "WindowThrowKeys"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
