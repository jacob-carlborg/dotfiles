// Runs `termzoom auto` at start and whenever the connected screens change.
// Built and started by `termzoom-watch`; see Library/LaunchAgents.

import AppKit

/// Runs one command, coalescing a burst of requests into a single run once
/// the requests have stopped for `delay` seconds.
final class DebouncedCommand {
    private let arguments: [String]
    private let delay: TimeInterval
    private var pending: DispatchWorkItem?

    init(arguments: [String], delay: TimeInterval) {
        self.arguments = arguments
        self.delay = delay
    }

    func request() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.run() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func run() {
        print(Date(), arguments.joined(separator: " "))
        fflush(stdout)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            FileHandle.standardError.write(Data("termzoom-watch: \(error)\n".utf8))
        }
    }
}

/// Calls `onChange` whenever screens are added, removed or rearranged.
final class ScreenWatcher {
    private let notifications: NotificationCenter
    private let onChange: () -> Void

    init(notifications: NotificationCenter = .default, onChange: @escaping () -> Void) {
        self.notifications = notifications
        self.onChange = onChange
    }

    func start() {
        notifications.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [onChange] _ in onChange() }
    }
}

// Screens report a change per display, and system_profiler lags behind the
// event, so wait for things to settle before looking.
let termzoom = DebouncedCommand(arguments: ["termzoom", "auto"], delay: 3)
ScreenWatcher(onChange: termzoom.request).start()
termzoom.run()

// macOS only delivers screen changes to a running application, not to a bare
// run loop, so run as one: no Dock icon, no menu bar.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.run()
