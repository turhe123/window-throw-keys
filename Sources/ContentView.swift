import SwiftUI

/// The Edit Actions window: action list on the left, the selected action's form on the right.
struct EditorView: View {
    @ObservedObject private var store = ActionStore.shared
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.actions) { action in
                    HStack {
                        Text(action.name)
                        Spacer()
                        Text(action.hotkey?.display ?? "").foregroundStyle(.secondary)
                    }
                    .tag(action.id)
                    .contextMenu {
                        Button("Run") { store.run(action) }
                        Button("Duplicate") { selection = store.duplicate(action.id) }
                        Button("Delete", role: .destructive) { store.delete(action.id) }
                    }
                }
                .onMove { store.actions.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { store.actions.remove(atOffsets: $0) }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            if store.actions.isEmpty {
                EmptyStateView()
            } else if let id = selection, let binding = binding(for: id) {
                ActionForm(action: binding).id(id)
            } else {
                Text("Select an action").foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { selection = store.add() } label: { Label("Add", systemImage: "plus") }
                Button { selection = store.captureNew() ?? selection } label: { Label("Capture Front Window", systemImage: "camera.viewfinder") }
                    .help("Create an action from the current front window's frame")
                Button { if let id = selection { selection = store.duplicate(id) } } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    .disabled(selection == nil)
                Button { if let id = selection { store.delete(id); selection = nil } } label: { Label("Delete", systemImage: "trash") }
                    .disabled(selection == nil)
                Menu {
                    Button("Add Starter Actions") { store.addStarters() }
                    Divider()
                    Button("Import Actions…") { store.importActions() }
                    Button("Export Actions…") { store.exportActions() }
                    Divider()
                    Button("Support / Donate ❤️") { openDonationPage() }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .onAppear { if selection == nil { selection = store.actions.first?.id } }
    }

    private func binding(for id: UUID) -> Binding<ThrowAction>? {
        guard let current = store.actions.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.actions.first(where: { $0.id == id }) ?? current },
            set: { newValue in
                if let i = store.actions.firstIndex(where: { $0.id == id }) { store.actions[i] = newValue }
            })
    }
}

/// Shown when there are no actions yet.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "macwindow.on.rectangle").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No throw actions yet").font(.title2)
            Text("Add your first action to send windows to a display, position and size with one hotkey.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 340)
            HStack {
                Button("Create Starter Actions") { ActionStore.shared.addStarters() }.buttonStyle(.borderedProminent)
                Button("Add Empty Action") { ActionStore.shared.add() }
            }
        }
        .padding()
    }
}

/// Form for editing one action: name, hotkey, display, frame percentages with live preview.
struct ActionForm: View {
    @Binding var action: ThrowAction
    @ObservedObject private var store = ActionStore.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @State private var captureError: String?

    var body: some View {
        Form {
            Section("Action") {
                TextField("Name", text: $action.name)
                LabeledContent("Hotkey") {
                    HotkeyRecorder(hotkey: $action.hotkey).frame(width: 170, height: 24)
                }
                let conflicts = store.conflicts(for: action)
                if !conflicts.isEmpty {
                    warning("Same shortcut as: \(conflicts.joined(separator: ", "))")
                } else if hotkeys.failed.contains(action.id) {
                    warning("This shortcut is already used by the system or another app.")
                }
            }
            Section("Target") {
                Picker("Display", selection: Binding(get: { action.display.tag }, set: { action.display = DisplayTarget(tag: $0) })) {
                    Text("Main Display").tag("main")
                    Text("Next Display").tag("next")
                    Text("Previous Display").tag("previous")
                    Divider()
                    ForEach(screenNames, id: \.self) { name in
                        Text(NSScreen.screens.contains { $0.localizedName == name } ? name : "\(name) (not connected)")
                            .tag(DisplayTarget.named(name).tag)
                    }
                }
                Toggle("Keep current size (only move)", isOn: $action.keepSize)
            }
            Section("Frame (% of visible area)") {
                HStack(spacing: 16) {
                    percentField("X", \.x)
                    percentField("Y", \.y)
                }
                HStack(spacing: 16) {
                    percentField("Width", \.width)
                    percentField("Height", \.height)
                }
                if action.exceedsDisplay {
                    warning("X + Width and Y + Height must not exceed 100%; the frame will be clamped to stay on screen.")
                }
                FramePreview(action: action).frame(height: 150).frame(maxWidth: .infinity)
                HStack {
                    Button("Use Current Window Frame") { useCurrentFrame() }
                    if let captureError { Text(captureError).font(.caption).foregroundStyle(.red) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var screenNames: [String] {
        var names = WindowMover.orderedScreens.map(\.localizedName)
        if case .named(let name) = action.display, !names.contains(name) { names.append(name) }
        return names
    }

    private func percentField(_ label: String, _ keyPath: WritableKeyPath<ThrowAction, Double>) -> some View {
        TextField(label, value: Binding(get: { action[keyPath: keyPath] },
                                        set: { action[keyPath: keyPath] = min(max($0, 0), 100) }),
                  format: .number.precision(.fractionLength(0...1)))
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
    }

    private func useCurrentFrame() {
        do {
            try WindowMover.shared.capture(into: &action)
            captureError = nil
        } catch {
            captureError = error.localizedDescription
        }
    }
}

/// A miniature display with the action's frame drawn inside it.
struct FramePreview: View {
    let action: ThrowAction

    private var aspect: CGFloat {
        var screen = NSScreen.screens.first
        if case .named(let name) = action.display {
            screen = NSScreen.screens.first { $0.localizedName == name } ?? screen
        }
        guard let size = screen?.visibleFrame.size, size.height > 0 else { return 16.0 / 10.0 }
        return size.width / size.height
    }

    var body: some View {
        GeometryReader { geo in
            let r = action.unitRect
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(action.keepSize ? 0.15 : 0.45))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: action.keepSize ? [4] : [])))
                    .frame(width: r.width * geo.size.width, height: r.height * geo.size.height)
                    .offset(x: r.minX * geo.size.width, y: r.minY * geo.size.height)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
    }
}
