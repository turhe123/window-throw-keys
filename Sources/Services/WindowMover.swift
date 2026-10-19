import AppKit
import ApplicationServices
import UserNotifications

/// Reasons a throw can fail.
enum ThrowError: LocalizedError {
    case notTrusted, noWindow, fullScreen, noScreen

    var errorDescription: String? {
        switch self {
        case .notTrusted: return "WindowThrowKeys needs Accessibility access. Enable it in System Settings › Privacy & Security › Accessibility."
        case .noWindow: return "No front window was found. Click a window in another app first."
        case .fullScreen: return "Full screen windows are skipped."
        case .noScreen: return "No display is available."
        }
    }
}

/// Finds the front window through the Accessibility API and moves/resizes it, converting between
/// AppKit (bottom-left origin) and Quartz (top-left origin) coordinates.
final class WindowMover {
    static let shared = WindowMover()

    /// The most recently active app other than ours, used when our own window has focus.
    private var lastExternalPID: pid_t?

    private init() {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() {
            lastExternalPID = front.processIdentifier
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier != getpid() {
                self?.lastExternalPID = app.processIdentifier
            }
        }
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Throwing

    /// Moves the front window per `action`. Returns the name of a missing named display if the fallback was used.
    func perform(_ action: ThrowAction) throws -> String? {
        guard AXIsProcessTrusted() else { throw ThrowError.notTrusted }
        guard let window = frontWindow() else { throw ThrowError.noWindow }
        if boolAttribute(window, "AXFullScreen") { throw ThrowError.fullScreen }
        guard let current = frame(of: window) else { throw ThrowError.noWindow }
        let currentAK = flip(current)
        guard let (screen, missing) = resolve(action.display, from: bestScreen(for: currentAK)) else { throw ThrowError.noScreen }

        let vf = screen.visibleFrame
        let r = action.unitRect
        var target = CGRect(x: vf.minX + r.minX * vf.width, y: vf.maxY - r.maxY * vf.height,
                            width: r.width * vf.width, height: r.height * vf.height)
        let resizable = !action.keepSize && isSettable(window, kAXSizeAttribute as String)
        if !resizable {
            target = CGRect(x: target.midX - current.width / 2, y: target.midY - current.height / 2,
                            width: current.width, height: current.height)
        }
        target = clamp(target, in: vf)

        let q = flip(target)
        if resizable { setSize(window, q.size) }
        setPosition(window, q.origin)
        if resizable { setSize(window, q.size) }

        // Some apps refuse or adjust the size; nudge the window back so it stays fully visible.
        if let actual = frame(of: window) {
            let fixed = clamp(flip(actual), in: vf)
            if fixed.origin != flip(actual).origin { setPosition(window, flip(fixed).origin) }
        }
        return missing
    }

    /// Fills `action` with the front window's display and frame percentages.
    func capture(into action: inout ThrowAction) throws {
        guard AXIsProcessTrusted() else { throw ThrowError.notTrusted }
        guard let window = frontWindow(), let quartz = frame(of: window) else { throw ThrowError.noWindow }
        let ak = flip(quartz)
        guard let screen = bestScreen(for: ak) else { throw ThrowError.noScreen }
        let vf = screen.visibleFrame
        func pct(_ v: CGFloat, _ total: CGFloat) -> Double { (min(max(Double(v / total) * 100, 0), 100) * 10).rounded() / 10 }
        action.width = max(pct(min(ak.width, vf.width), vf.width), 1)
        action.height = max(pct(min(ak.height, vf.height), vf.height), 1)
        action.x = min(pct(ak.minX - vf.minX, vf.width), 100 - action.width)
        action.y = min(pct(vf.maxY - ak.maxY, vf.height), 100 - action.height)
        action.display = .named(screen.localizedName)
        action.keepSize = false
    }

    // MARK: Displays

    /// Screens ordered left-to-right, used for Next / Previous.
    static var orderedScreens: [NSScreen] {
        NSScreen.screens.sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
    }

    private func resolve(_ target: DisplayTarget, from current: NSScreen?) -> (NSScreen, String?)? {
        let screens = Self.orderedScreens
        guard let main = NSScreen.screens.first else { return nil }
        let index = current.flatMap { c in screens.firstIndex(of: c) } ?? 0
        switch target {
        case .main: return (main, nil)
        case .next: return (screens[(index + 1) % screens.count], nil)
        case .previous: return (screens[(index - 1 + screens.count) % screens.count], nil)
        case .named(let name):
            if let match = screens.first(where: { $0.localizedName == name }) { return (match, nil) }
            return (main, name)
        }
    }

    private func bestScreen(for rect: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in area(a.frame.intersection(rect)) < area(b.frame.intersection(rect)) }
    }

    private func area(_ r: CGRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }

    /// Converts between AppKit and Quartz rects (the transform is its own inverse).
    private func flip(_ r: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    /// Shrinks `r` to fit and keeps it inside `bounds`; oversized windows are pinned to the top-left.
    private func clamp(_ r: CGRect, in bounds: CGRect) -> CGRect {
        var r = r
        r.origin.x = max(min(r.minX, bounds.maxX - r.width), bounds.minX)
        r.origin.y = min(max(r.minY, bounds.minY), bounds.maxY - r.height)
        return r
    }

    // MARK: Accessibility helpers

    private func frontWindow() -> AXUIElement? {
        var pid: pid_t = 0
        if let app = element(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as String) {
            AXUIElementGetPid(app, &pid)
        }
        if pid == 0 || pid == getpid() { pid = lastExternalPID ?? 0 }
        guard pid != 0 else { return nil }
        let app = AXUIElementCreateApplication(pid)
        return element(app, kAXFocusedWindowAttribute as String) ?? element(app, kAXMainWindowAttribute as String)
    }

    private func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func boolAttribute(_ el: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func isSettable(_ el: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(el, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private func frame(of el: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef,
              CFGetTypeID(posRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private func setPosition(_ el: AXUIElement, _ point: CGPoint) {
        var p = point
        if let value = AXValueCreate(.cgPoint, &p) {
            AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, value)
        }
    }

    private func setSize(_ el: AXUIElement, _ size: CGSize) {
        var s = size
        if let value = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, value)
        }
    }
}

/// Posts optional user notifications (only when enabled in Settings).
enum Notifier {
    static let enabledKey = "notifyOnFallback"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func displayMissing(_ display: String, action: String) {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Display “\(display)” not connected"
        content.body = "“\(action)” used the main display instead."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
