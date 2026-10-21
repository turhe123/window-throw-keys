# WindowThrowKeys

**🌐 Website:** [turhe123.github.io/window-throw-keys](https://turhe123.github.io/window-throw-keys/)

Assign a hotkey to throw the front window to a chosen display at an exact position and size.

> 🆓 A free, open-source **Hookshot alternative** for macOS 14+. Native Swift, no accounts, no subscriptions, MIT licensed.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![GitHub release](https://img.shields.io/github/v/release/turhe123/window-throw-keys)

## Why

WindowThrowKeys is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Window Management* category. It was inspired by Hookshot ($9.99 one-time), which pioneered custom shortcuts that send a window to a specific display, position and size. There is no account, no server and no network code: your actions live in a JSON file on your Mac.

## Features

- **User-defined throw actions**: each has a name, a global hotkey, a target display and a frame.
- **Display targets**: Main, Next, Previous (displays are ordered left to right and wrap around), or a specific display by name. If a named display is not connected, the action falls back to the Main display.
- **Exact frames as percentages** of the target display's visible area (X, Y, Width, Height), clamped so the window never leaves the screen.
- **Keep current size** option: move the window without resizing it. The window is centred in the frame.
- **Capture**: create a new action from the front window's current frame, or fill an existing action with "Use Current Window Frame".
- **Live preview**: a miniature display shows where the frame will land.
- **Hotkey recorder** with conflict warnings when two actions share a shortcut, and a warning if the system or another app already owns it.
- **Starter actions**: Send to Next Display, Send to Previous Display, Center at 60%, Left Two Thirds.
- **Edit tools**: duplicate, reorder, delete, and import/export all actions as JSON.
- **Menu bar app**: lists every action with its shortcut; click one to run it on the front window.
- **Launch at login** via `SMAppService`.
- **Optional notification** when a named display is not connected (off by default).
- Full screen windows are skipped. Windows that can't be resized are moved and kept fully visible.

## Screenshots

<p align="center"><img src="docs/screenshots/01-menu.png" alt="WindowThrowKeys menu bar menu listing throw actions and shortcuts" width="720"></p>

<p align="center"><em>The menu bar menu lists every throw action with its global hotkey click one to send the front window to its display and frame.</em></p>

<p align="center"><img src="docs/screenshots/02-editor.png" alt="Edit Actions window showing the Left Two Thirds action with a frame preview" width="560"></p>

<p align="center"><em>The action editor sets each action&#x27;s name, hotkey, target display and frame percentages, with a live preview of where the window will land.</em></p>

<p align="center"><img src="docs/screenshots/03-settings.png" alt="WindowThrowKeys Settings window" width="560"></p>

<p align="center"><em>Settings has launch at login, the optional missing-display notification, and the Accessibility permission status.</em></p>

## Install

1. Download `WindowThrowKeys-macOS.zip` from the [latest release](https://github.com/turhe123/window-throw-keys/releases/latest).
2. Unzip it and move `WindowThrowKeys.app` to `/Applications`.
3. The app is open source and not notarized, so macOS will quarantine it. Run:

   ```bash
   xattr -cr /Applications/WindowThrowKeys.app
   ```

4. The first time, right-click the app and choose **Open**.

## Build from source

Requires macOS 14+ and Xcode with Swift 5.9+.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project WindowThrowKeys.xcodeproj -scheme WindowThrowKeys -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/WindowThrowKeys.app`.

## Permissions

| Permission | Required? | Why |
| --- | --- | --- |
| **Accessibility** | Yes | Used to find the front window and read/set its position and size. The app prompts on launch and shows the status in Settings. Enable it in System Settings › Privacy & Security › Accessibility. |
| **Notifications** | Optional | Only requested if you turn on "Notify when a named display is not connected" in Settings. |
| **Login item** | Optional | Only if you turn on "Launch at login". |

WindowThrowKeys does **not** request Screen Recording or Microphone access, and it makes no network connections. It never reads window contents, only window frames.

## Built with AI

WindowThrowKeys was written by [Claude Code](https://claude.com/claude-code) inside an automated pipeline, from a plain-English spec. No code, binaries or assets from any commercial app were used; it is a clean-room reimplementation of a feature set, not a copy.

What that means in practice:

- The full source is in this repo under the MIT license. Read it before you run it.
- No network calls, no analytics, no third-party dependencies. Only Apple frameworks.
- Ad-hoc signed and not notarized, which is why Gatekeeper warns on first launch.
- It has had less human review than a hand-written app. Bug reports and pull requests are welcome.

## Support ❤️

WindowThrowKeys is free. If it saves you time, you can support its development:

[☕ Support Or (Leo) Davidai ❤️ on Ko-fi](https://ko-fi.com/leodavidai)

The app also has a **Support / Donate ❤️** button in the menu bar menu, Settings and the editor.

## More free Mac apps

WindowThrowKeys is one of a growing collection of [free, open-source Mac utilities](https://github.com/turhe123/mac-apps) built the same way: native Swift, no accounts, no telemetry. Browse the full gallery at [turhe123.github.io/mac-apps](https://turhe123.github.io/mac-apps/).

Prefer something that runs in the browser? The same pipeline builds [free, private web tools](https://turhe123.github.io/web-tools/): PDF, image, developer, data and audio tools, nothing uploaded.

## License

MIT © Or Davidai Bachar
