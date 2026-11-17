// Runs `termzoom auto` at start and whenever the connected screens change.
// Built and started by `termzoom-watch`; see Library/LaunchAgents.

import CoreGraphics
import Foundation

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

/// Calls `onChange` after each screen reconfiguration completes.
final class ScreenWatcher {
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let context = Unmanaged.passRetained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            guard let context, !flags.contains(.beginConfigurationFlag) else { return }
            Unmanaged<ScreenWatcher>.fromOpaque(context).takeUnretainedValue().onChange()
        }, context)
    }
}

// Screens report a change per display, and system_profiler lags behind the
// event, so wait for things to settle before looking.
let termzoom = DebouncedCommand(arguments: ["termzoom", "auto"], delay: 3)
ScreenWatcher(onChange: termzoom.request).start()

termzoom.run()
RunLoop.main.run()
