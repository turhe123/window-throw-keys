import SwiftUI
import Carbon.HIToolbox

/// SwiftUI wrapper around `RecorderView` for recording a global shortcut.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey?

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.hotkey = hotkey
        view.onChange = { hotkey = $0 }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.onChange = { hotkey = $0 }
        if !view.isRecording { view.hotkey = hotkey }
    }
}

/// Click to focus, then press a modifier + key combination. Esc cancels, Delete clears.
final class RecorderView: NSView {
    var hotkey: Hotkey? { didSet { needsDisplay = true } }
    var onChange: ((Hotkey?) -> Void)?
    private(set) var isRecording = false {
        didSet {
            needsDisplay = true
            HotkeyManager.shared.suspended = isRecording
        }
    }

    private static let specialKeys: [Int: String] = [
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(isRecording ? nil : self)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        let code = Int(event.keyCode)
        if code == kVK_Escape {
            window?.makeFirstResponder(nil)
            return
        }
        if code == kVK_Delete || code == kVK_ForwardDelete {
            finish(nil)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }

        let special = Self.specialKeys[code]
        let isFunctionKey = special?.hasPrefix("F") == true
        guard mods & ~UInt32(shiftKey) != 0 || isFunctionKey else {
            NSSound.beep() // require ⌘, ⌥ or ⌃ so plain typing is never hijacked
            return
        }
        let label = special ?? (event.charactersIgnoringModifiers ?? "?").uppercased()
        finish(Hotkey(keyCode: UInt32(code), modifiers: mods, label: label))
    }

    private func finish(_ value: Hotkey?) {
        hotkey = value
        onChange?(value)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()

        let text = isRecording ? "Type shortcut…" : (hotkey?.display ?? "Click to record")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: hotkey == nil || isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
    }
}
