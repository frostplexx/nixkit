import Cocoa
import Foundation

// MARK: - Terminal

enum Terminal: String, CaseIterable {
    case terminal  = "terminal"
    case iterm     = "iterm"
    case kitty     = "kitty"
    case alacritty = "alacritty"
    case ghostty   = "ghostty"

    static var names: String {
        allCases.map { $0.rawValue }.joined(separator: ", ")
    }

    /// Bundle identifier used to check if the app is installed
    var bundleID: String {
        switch self {
        case .terminal:  return "com.apple.Terminal"
        case .iterm:     return "com.googlecode.iterm2"
        case .kitty:     return "net.kovidgoyal.kitty"
        case .alacritty: return "org.alacritty"
        case .ghostty:   return "com.mitchellh.ghostty"
        }
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}

// MARK: - Config

struct Config {
    var interval: TimeInterval = 30 * 60
    var flakePath: String?     = nil
    var updateCommand: String  = "jinx update"
    var terminal: Terminal     = .terminal
}

func parseArgs() -> Config {
    var config = Config()
    let args = CommandLine.arguments.dropFirst()
    var i = args.startIndex

    func next(_ flag: String) -> String {
        i = args.index(after: i)
        guard i < args.endIndex else {
            fputs("error: \(flag) requires a value\n", stderr)
            exit(1)
        }
        return args[i]
    }

    while i < args.endIndex {
        switch args[i] {
        case "-h", "--help":
            print("""
            Usage: NixUpdater [options]

              -i, --interval <seconds>    Auto-check interval (default: 1800)
              -f, --flake <path>          Git repo path (overrides $NH_FLAKE)
              -c, --command <cmd>         Update command (default: "jinx update")
              -t, --terminal <name>       Terminal to use (default: terminal)
                                          Options: \(Terminal.names)
              -h, --help                  Show this help
            """)
            exit(0)

        case "-i", "--interval":
            let raw = next("--interval")
            guard let secs = Double(raw), secs > 0 else {
                fputs("error: --interval must be a positive number\n", stderr)
                exit(1)
            }
            config.interval = secs

        case "-f", "--flake":
            config.flakePath = next("--flake")

        case "-c", "--command":
            config.updateCommand = next("--command")

        case "-t", "--terminal":
            let raw = next("--terminal").lowercased()
            guard let t = Terminal(rawValue: raw) else {
                fputs("error: unknown terminal '\(raw)'. Options: \(Terminal.names)\n", stderr)
                exit(1)
            }
            config.terminal = t

        default:
            fputs("error: unknown argument '\(args[i])'\n", stderr)
            exit(1)
        }

        i = args.index(after: i)
    }

    return config
}

// MARK: - Constants

let kPATH = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var updateChecker: UpdateChecker!
    let config: Config

    /// Tracks the Process handle for terminals launched as child processes
    /// (kitty, alacritty, ghostty) so we can terminate them after completion.
    private var terminalProcess: Process?

    /// For AppleScript-based terminals we store the tab/window identifier
    /// so we can close it when the update finishes.
    private var terminalTabID: String?

    init(config: Config) {
        self.config = config
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.image = statusImage(symbol: "square.and.arrow.down.badge.clock.fill")
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateChecker = UpdateChecker(statusItem: statusItem, config: config)
        updateChecker.check()

        Timer.scheduledTimer(withTimeInterval: config.interval, repeats: true) { [weak self] _ in
            self?.updateChecker.check()
        }
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp { showMenu() } else { openTerminalAndUpdate() }
    }

    func showMenu() {
        let menu = NSMenu()

        // Status
        let statusTitle: String
        if let behind = updateChecker.behindCount {
            statusTitle = behind == 0
                ? "Up to date"
                : "\(behind) commit\(behind == 1 ? "" : "s") behind upstream"
        } else {
            statusTitle = "Checking for updates..."
        }
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        if let behind = updateChecker.behindCount, behind > 0 {
            let repoItem = NSMenuItem(title: "Repo: \(updateChecker.repoName)", action: nil, keyEquivalent: "")
            repoItem.isEnabled = false
            menu.addItem(repoItem)
        }

        // Interval
        let mins = Int(config.interval / 60)
        let intervalLabel = mins >= 60
            ? "Refresh every \(mins / 60)h\(mins % 60 > 0 ? " \(mins % 60)m" : "")"
            : "Refresh every \(mins)m"
        let intervalItem = NSMenuItem(title: intervalLabel, action: nil, keyEquivalent: "")
        intervalItem.isEnabled = false
        menu.addItem(intervalItem)


        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Check Now", action: #selector(checkNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: "Run Update Command…", action: #selector(openTerminalAndUpdate), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    @objc func checkNow() { updateChecker.check() }

    private func statusImage(symbol: String) -> NSImage? {
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    /// Resolve the flake directory path from config or environment.
    private func resolvedFlakePath() -> String? {
        let raw: String
        if let override = config.flakePath {
            raw = override
        } else if let env = ProcessInfo.processInfo.environment["NH_FLAKE"] {
            raw = env
        } else {
            return nil
        }

        return raw.hasPrefix("/")
            ? raw
            : (raw as NSString).expandingTildeInPath
    }

    @objc func openTerminalAndUpdate() {
        let fishPath = kPATH.replacingOccurrences(of: ":", with: " ")

        let sentinel  = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nixupdater-done-\(UUID().uuidString)")
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nixupdater-run-\(UUID().uuidString).fish")

        // Resolve the flake directory so the command runs inside it.
        let flakeDir = resolvedFlakePath()

        var fishLines: [String] = []
        fishLines.append("set -x PATH \(fishPath)")
        if let dir = flakeDir {
            fishLines.append("cd \(dir); or begin; echo 'Failed to cd into flake directory'; read -P \"Press Enter to close...\"; touch \(sentinel.path); exit 1; end")
        }
        fishLines.append(config.updateCommand)
        fishLines.append("read -P \"Press Enter to close...\"")
        fishLines.append("touch \(sentinel.path)")
        fishLines.append("exit 0")

        let fishScript = fishLines.joined(separator: "\n")

        do {
            try fishScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                  ofItemAtPath: scriptURL.path)
        } catch {
            return
        }

        let fishBin = "/run/current-system/sw/bin/fish"
        let fishCmd = "\(fishBin) --no-config \(scriptURL.path)"

        switch config.terminal {

        case .terminal:
            // Terminal.app: open a new window, capture its ID, and close it
            // when the sentinel appears.
            runAppleScript("""
            tell application "Terminal"
                activate
                set newTab to do script "\(fishCmd)"
            end tell
            """)

            watchSentinel(sentinel) { [weak self] in
                try? FileManager.default.removeItem(at: sentinel)
                try? FileManager.default.removeItem(at: scriptURL)
                self?.closeTerminalApp()
                self?.updateChecker.check()
            }

        case .iterm:
            runAppleScript("""
            tell application "iTerm"
                activate
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(fishCmd)"
                    end tell
                end tell
            end tell
            """)

            watchSentinel(sentinel) { [weak self] in
                try? FileManager.default.removeItem(at: sentinel)
                try? FileManager.default.removeItem(at: scriptURL)
                self?.closeItermSession()
                self?.updateChecker.check()
            }

        case .kitty:
            let proc = launchProcess("/usr/bin/env",
                                     args: ["kitty", fishBin, "--no-config", scriptURL.path])
            terminalProcess = proc

            watchSentinel(sentinel) { [weak self] in
                try? FileManager.default.removeItem(at: sentinel)
                try? FileManager.default.removeItem(at: scriptURL)
                self?.terminateChildProcess()
                self?.updateChecker.check()
            }

        case .alacritty:
            let proc = launchProcess("/usr/bin/env",
                                     args: ["alacritty", "-e", fishBin, "--no-config", scriptURL.path])
            terminalProcess = proc

            watchSentinel(sentinel) { [weak self] in
                try? FileManager.default.removeItem(at: sentinel)
                try? FileManager.default.removeItem(at: scriptURL)
                self?.terminateChildProcess()
                self?.updateChecker.check()
            }

        case .ghostty:
            let ghosttyPaths = [
                "/Applications/Ghostty.app/Contents/MacOS/ghostty",
                "/opt/homebrew/bin/ghostty",
                "/usr/local/bin/ghostty",
            ]
            let ghostty = ghosttyPaths.first { FileManager.default.fileExists(atPath: $0) } ?? "ghostty"
            let proc = launchProcess(ghostty,
                                     args: ["-e", fishBin, "--no-config", scriptURL.path])
            terminalProcess = proc

            watchSentinel(sentinel) { [weak self] in
                try? FileManager.default.removeItem(at: sentinel)
                try? FileManager.default.removeItem(at: scriptURL)
                self?.terminateChildProcess()
                self?.updateChecker.check()
            }
        }
    }

    // MARK: - Terminal Closing Helpers

    /// Close the most recently opened Terminal.app window whose shell has exited.
    private func closeTerminalApp() {
        // The fish script has already exited. Tell Terminal.app to close
        // any window/tab whose process has finished (i.e. is not busy).
        // We target windows running our fish script by checking if the
        // shell has exited — Terminal marks those tabs as "not busy".
        runAppleScript("""
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if busy of t is false then
                        close w
                        return
                    end if
                end repeat
            end repeat
        end tell
        """)
    }

    /// Close the current iTerm session/tab that was running our command.
    private func closeItermSession() {
        runAppleScript("""
        tell application "iTerm"
            tell current window
                tell current session
                    close
                end tell
            end tell
        end tell
        """)
    }

    /// Terminate a child process (kitty, alacritty, ghostty) that we launched
    /// directly. The fish script has already exited so the process should be
    /// winding down, but we make sure by sending SIGTERM then waiting briefly
    /// before sending SIGKILL if it's still running.
    private func terminateChildProcess() {
        guard let proc = terminalProcess else { return }
        terminalProcess = nil

        if proc.isRunning {
            proc.terminate()  // SIGTERM

            // Give the process a moment to exit gracefully.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                if proc.isRunning {
                    // Force kill if it's still hanging around.
                    kill(proc.processIdentifier, SIGKILL)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Watches for `sentinel` to be created, then fires `handler` on the main queue.
    private func watchSentinel(_ sentinel: URL, handler: @escaping () -> Void) {
        let queue = DispatchQueue.global(qos: .utility)
        queue.async {
            while !FileManager.default.fileExists(atPath: sentinel.path) {
                Thread.sleep(forTimeInterval: 2)
            }
            DispatchQueue.main.async { handler() }
        }
    }

    private func runAppleScript(_ source: String) {
        if let script = NSAppleScript(source: source) {
            var err: NSDictionary?
            script.executeAndReturnError(&err)
        }
    }

    @discardableResult
    private func launchProcess(_ path: String, args: [String]) -> Process? {
        let task = Process()
        task.launchPath = FileManager.default.fileExists(atPath: path) ? path : "/usr/bin/env"
        task.arguments  = FileManager.default.fileExists(atPath: path) ? args : [path] + args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = kPATH
        task.environment = env
        do {
            try task.run()
            return task
        } catch {
            return nil
        }
    }
}

// MARK: - UpdateChecker

class UpdateChecker {
    var behindCount: Int? = nil
    var repoName: String  = ""
    private let statusItem: NSStatusItem
    private let config: Config

    init(statusItem: NSStatusItem, config: Config) {
        self.statusItem = statusItem
        self.config     = config
    }

    func check() {
        DispatchQueue.main.async {
            self.statusItem.button?.image = self.statusImage(symbol: "square.and.arrow.down.badge.clock.fill")
            self.statusItem.button?.title = ""
        }
        DispatchQueue.global(qos: .background).async { self.performCheck() }
    }

    private func performCheck() {
        let flakePath: String
        if let override = config.flakePath {
            flakePath = override
        } else if let env = ProcessInfo.processInfo.environment["NH_FLAKE"] {
            flakePath = env
        } else {
            updateUI(error: "NH_FLAKE not set"); return
        }

        let repoPath = flakePath.hasPrefix("/")
            ? flakePath
            : (flakePath as NSString).expandingTildeInPath

        if let url = shell("git", args: ["-C", repoPath, "remote", "get-url", "origin"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            let name = url
                .replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            DispatchQueue.main.async { self.repoName = name }
        }

        _ = shell("git", args: ["-C", repoPath, "fetch", "--quiet"])

        let upstream = shell("git", args: ["-C", repoPath, "rev-parse",
                                           "--abbrev-ref", "--symbolic-full-name", "@{u}"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "origin/main"

        guard let countStr = shell("git", args: ["-C", repoPath, "rev-list",
                                                 "--count", "HEAD..\(upstream)"])?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let count = Int(countStr) else {
            updateUI(error: "Git error"); return
        }

        DispatchQueue.main.async {
            self.behindCount = count
            self.updateStatusBar(behind: count)
        }
    }

    private func updateUI(error: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = self.statusImage(symbol: "exclamationmark.triangle.fill")
            self.statusItem.button?.title = ""
            self.statusItem.button?.toolTip = error
        }
    }

    private func updateStatusBar(behind: Int) {
        let symbol = behind == 0
            ? "square.and.arrow.down.badge.checkmark.fill"
            : "square.and.arrow.down.badge.clock.fill"
        statusItem.button?.image = statusImage(symbol: symbol)
        statusItem.button?.title = behind > 0 ? " \(behind)" : ""
        statusItem.button?.toolTip = behind == 0 ? "Up to date" : "\(behind) update\(behind == 1 ? "" : "s") available"
    }

    private func statusImage(symbol: String) -> NSImage? {
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    private func shell(_ command: String, args: [String]) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments  = [command] + args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = kPATH
        task.environment = env
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        do { try task.run() } catch { return nil }
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

// MARK: - Entry Point

let config = parseArgs()
let app    = NSApplication.shared
let delegate = AppDelegate(config: config)
app.delegate = delegate
app.run()
