import Foundation
import Carbon.HIToolbox

/// A recorded keyboard shortcut: a Carbon virtual key code, a Carbon modifier mask and a display label.
struct Hotkey: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    /// Human-readable shortcut such as "⌃⌥⌘→".
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + label
    }

    /// True when both shortcuts would trigger on the same key press.
    func collides(with other: Hotkey) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

/// The display an action throws the window to.
enum DisplayTarget: Codable, Hashable {
    case main, next, previous
    case named(String)

    /// Stable string used as a SwiftUI picker tag.
    var tag: String {
        switch self {
        case .main: return "main"
        case .next: return "next"
        case .previous: return "previous"
        case .named(let name): return "name:" + name
        }
    }

    init(tag: String) {
        switch tag {
        case "next": self = .next
        case "previous": self = .previous
        case let t where t.hasPrefix("name:"): self = .named(String(t.dropFirst(5)))
        default: self = .main
        }
    }
}

/// A user-defined "throw": a hotkey plus the display and frame (in percent of the visible area) to move the window to.
struct ThrowAction: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hotkey: Hotkey?
    var display: DisplayTarget = .main
    var x: Double = 0
    var y: Double = 0
    var width: Double = 100
    var height: Double = 100
    /// When true the window keeps its size and is centred inside the frame instead of filling it.
    var keepSize = false

    /// The frame as unit fractions (0...1, y measured from the top), clamped so it never leaves the display.
    var unitRect: CGRect {
        let w = min(max(width, 1), 100)
        let h = min(max(height, 1), 100)
        let px = min(max(x, 0), 100 - w)
        let py = min(max(y, 0), 100 - h)
        return CGRect(x: px / 100, y: py / 100, width: w / 100, height: h / 100)
    }

    /// True when the raw percentages would extend past the display edge (they get clamped at run time).
    var exceedsDisplay: Bool { x + width > 100.001 || y + height > 100.001 }

    /// The built-in starter set.
    static var starters: [ThrowAction] {
        let mods = UInt32(controlKey | optionKey | cmdKey)
        return [
            ThrowAction(name: "Send to Next Display", hotkey: Hotkey(keyCode: UInt32(kVK_RightArrow), modifiers: mods, label: "→"),
                        display: .next, keepSize: true),
            ThrowAction(name: "Send to Previous Display", hotkey: Hotkey(keyCode: UInt32(kVK_LeftArrow), modifiers: mods, label: "←"),
                        display: .previous, keepSize: true),
            ThrowAction(name: "Center at 60%", hotkey: Hotkey(keyCode: UInt32(kVK_ANSI_C), modifiers: mods, label: "C"),
                        x: 20, y: 20, width: 60, height: 60),
            ThrowAction(name: "Left Two Thirds", hotkey: Hotkey(keyCode: UInt32(kVK_ANSI_L), modifiers: mods, label: "L"),
                        width: 66.7, height: 100),
        ]
    }
}
