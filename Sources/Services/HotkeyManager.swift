import Carbon.HIToolbox
import Foundation

/// Carbon event callback: forwards hotkey presses to the shared manager on the main queue.
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    DispatchQueue.main.async { HotkeyManager.shared.fire(hotKeyID.id) }
    return noErr
}

/// Registers global hotkeys with Carbon `RegisterEventHotKey` and maps each hotkey id back to its action.
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    /// Actions whose shortcut could not be registered (taken by the system, another app, or another action).
    @Published private(set) var failed: Set<UUID> = []

    /// While true (e.g. during shortcut recording) no hotkeys are registered.
    var suspended = false {
        didSet { if suspended != oldValue { register(lastActions) } }
    }

    private let signature: OSType = 0x5754_4B59 // "WTKY"
    private var refs: [EventHotKeyRef] = []
    private var actionByHotkeyID: [UInt32: UUID] = [:]
    private var lastActions: [ThrowAction] = []
    private var handlerInstalled = false

    func register(_ actions: [ThrowAction]) {
        lastActions = actions
        installHandlerIfNeeded()
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actionByHotkeyID.removeAll()
        guard !suspended else { return }

        var failures = Set<UUID>()
        var registered: [Hotkey] = []
        var nextID: UInt32 = 1
        for action in actions {
            guard let hk = action.hotkey else { continue }
            if registered.contains(where: { $0.collides(with: hk) }) {
                failures.insert(action.id)
                continue
            }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(hk.keyCode, hk.modifiers, EventHotKeyID(signature: signature, id: nextID),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                actionByHotkeyID[nextID] = action.id
                registered.append(hk)
            } else {
                failures.insert(action.id)
            }
            nextID += 1
        }
        if failures != failed { failed = failures }
    }

    func fire(_ hotKeyID: UInt32) {
        guard let actionID = actionByHotkeyID[hotKeyID] else { return }
        ActionStore.shared.run(id: actionID)
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerInstalled = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil) == noErr
    }
}
