---
name: screencapture-qemu
description: Take a screenshot of a running QEMU guest window on macOS. Works for any qemu-system-* binary (x86_64, aarch64, riscv64, ppc64, sparc64, etc.) since it filters by the shared `qemu-system-` owner-name prefix. Use when the user asks for a QEMU/VM screencap to debug a guest. Requires QEMU launched with `-display cocoa`.
---

# Screencapture a QEMU guest window

QEMU's macOS Cocoa window is owned by the `qemu-system-<arch>` binary itself. Every architecture shares the `qemu-system-` prefix, and the window title is `QEMU <vm-name>` when `-name <vm-name>` is set (or just `QEMU` otherwise).

## Step 1 — find the QEMU window

```sh
swift - <<'EOF'
import Cocoa
let ws = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in ws {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
    let title = (w[kCGWindowName as String] as? String) ?? ""
    guard owner.hasPrefix("qemu-system-") else { continue }
    let id  = w[kCGWindowNumber as String] as? Int ?? -1
    let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1
    print("\(id)\t\(pid)\t\(owner)\t\(title)")
}
EOF
```

Filtering on the `qemu-system-` prefix is what makes this work across architectures — never hard-code `qemu-system-x86_64`.

## Step 2 — pick the guest framebuffer window

QEMU registers several CGWindows per process (the menu bar, hidden helpers, the visible guest window). The guest framebuffer is the row whose **title starts with `QEMU`** and is non-empty — pick that one.

If multiple QEMU instances are running (e.g. parallel Packer builds), disambiguate by the VM name baked into the title. With Packer that's the `vm_name` of the source; with raw `qemu-system-*` invocations it's whatever was passed via `-name <foo>`.

## Step 3 — capture

```sh
screencapture -l <windowid> -x <output.png>
```

## Notes

- `-display cocoa` is required for a window to exist. With `headless=true` (Packer) or `-display none` there's nothing to capture.
- Window IDs are stable for the lifetime of the QEMU process, so caching the ID across repeat snapshots is fine.
- The captured framebuffer is at native resolution — text-mode console output (e.g. early kernel messages, rc shell prompts) is sharp and OCR-friendly.
- If you need to capture early-boot output that scrolls off-screen, prefer `-serial file:<path>` over relying on screenshots; pair the two for full coverage.
