# WindowThrowKeys — specification

**Tagline:** Assign a hotkey to throw the front window to a chosen display at an exact position and size.

**Category:** Window Management

**Inspired by (paid):** Hookshot ($9.99 one-time)

**Frameworks:** SwiftUI, AppKit, ApplicationServices, CoreGraphics, Carbon, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

(1) What the paid app does. Hookshot is a paid window mover that lets you create custom shortcuts that send a window to a specific display, in a specific position and with precise dimensions, going beyond fixed halves and thirds. Reviewers describe it as costing under ten dollars and as the tool for people with multi-monitor desks who want repeatable arrangement. Demand shows in blog walkthroughs and recurring mentions next to Rectangle and Magnet. Our clean-room version is WindowThrowKeys.

(2) Feature set. A list of user-defined throw actions. Each action has a name, a hotkey, a target display chosen from Main, Next, Previous, or a specific display by name, a frame defined in percentages of that display's visible area (x, y, width, height), and an option for keeping the current size and only moving. Pressing the hotkey moves the front window of the active app to that frame. Built-in starter actions: Send to Next Display, Send to Previous Display, Center at 60 percent, and Left Two Thirds. A capture button records the current front window's frame as a new action's rectangle. Actions can be duplicated, reordered and deleted. Import and export actions as a JSON file.

(3) UI spec. Menu bar extra with the list of actions and their shortcuts, clicking one runs it on the front window, plus Edit Actions, Settings and Quit. The main Edit Actions window is a SwiftUI split view with the action list on the left and a form on the right: name field, hotkey recorder, display picker, four numeric fields for percentages with a small live preview rectangle drawn inside a miniature display, a Use Current Window Frame button, and a keep size toggle. Empty state shows a prompt to add the first action with a button that creates the starter set. Settings holds launch at login and the Accessibility status row.

(4) Technical approach. Use Accessibility trust via AXIsProcessTrustedWithOptions. Get the front window using the system-wide AX element focused application and its focused window attribute. Write position and size attributes using AXValueCreate with CGPoint and CGSize. Convert between AppKit and Quartz coordinates using the primary screen height. Resolve displays with NSScreen screens, using localizedName for named matching and falling back to Main if the named display is not connected. Register hotkeys with Carbon RegisterEventHotKey, maintaining a dictionary from hotkey id to action. Persist actions as Codable JSON in Application Support and settings through AppStorage. Use SMAppService for launch at login. Hotkey recording is a small NSViewRepresentable that captures key down events. Target around 520 lines.

(5) Edge cases. If a window cannot be resized, move it and clamp it so it stays visible. Apply size before and after the position because some apps adjust one when the other changes, a known quirk when crossing displays with different scale. Detect hotkey conflicts between actions and warn in the form. Skip full screen windows. Handle a disconnected named display by running the fallback and showing a brief notification through UserNotifications only when the user enables it. Validate percentages to stay between 0 and 100 and sum constraints so the frame never extends off screen.
