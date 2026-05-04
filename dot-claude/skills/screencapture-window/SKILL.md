---
name: screencapture-window
description: Take a screenshot of a specific macOS window non-interactively by querying CGWindowList for windows matching an owner-name or title substring, then invoking `screencapture -l <windowid>`. Use when the user asks to screencap, screenshot, or capture a specific app/window without clicking. macOS only.
---

# Screencapture a window

## Step 1 — find the window ID

CGWindowList is the only reliable enumerator on macOS — `osascript` / "System Events" does NOT see windows from non-bundled binaries (e.g. raw CLI apps that just open an NSWindow). Use this Swift one-liner:

```sh
swift - <<'EOF' "<search-term>"
import Cocoa
let needle = (CommandLine.arguments.dropFirst().first ?? "").lowercased()
let ws = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in ws {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
    let title = (w[kCGWindowName as String] as? String) ?? ""
    if needle.isEmpty || owner.lowercased().contains(needle) || title.lowercased().contains(needle) {
        let id  = w[kCGWindowNumber as String] as? Int ?? -1
        let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1
        print("\(id)\t\(pid)\t\(owner)\t\(title)")
    }
}
EOF
```

It prints `<windowid>\t<pid>\t<owner>\t<title>` for every match. Pass an empty string to dump every window.

## Step 2 — pick the right window

Multiple rows are normal — apps create helper/IME/menu windows. **Prefer the row whose title is non-empty**; that's almost always the visible main window. If several have non-empty titles, choose by the closest title match.

## Step 3 — capture

```sh
screencapture -l <windowid> -x <output.png>
```

- `-l <windowid>` captures by CGWindowID.
- `-x` suppresses the camera-shutter sound.

The output is the window's contents (no decorations or shadow).

## Notes

- Window IDs are stable for the lifetime of a process, so for repeated captures you can cache the ID once.
- `[.optionAll]` includes off-screen windows. Minimised-to-Dock windows still won't render anything useful — un-minimise them or use `[.optionOnScreenOnly]` to filter them out.
- For interactive use cases (mouse-pick a window), `screencapture -W` exists. This skill is specifically for the *non-interactive* path.
