import Carbon
import Cocoa
import Foundation

// Global reference to HyperKey instance (to call methods from signal handlers)
var hyperKeyInstance: HyperKey? = nil

// C function to handle signals
func handleSignal(_ signal: Int32) {
    // Call the reset function on the HyperKey instance
    hyperKeyInstance?.resetKeyMapping()
    exit(0)  // Exit after resetting key mappings
}

// MARK: - CapsLock Manager
// Source: https://github.com/gkpln3/CapsLockNoDelay

protocol Toggleable {
    func toggleState()
}

class CapsLockManager: Toggleable {
    var currentState = false

    init() {
        currentState = Self.getCapsLockState()
    }

    public func toggleState() {
        self.setCapsLockState(!self.currentState)
    }

    public func setCapsLockState(_ state: Bool) {
        self.currentState = state
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        IOServiceOpen(
            ioService,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &ioConnect
        )
        IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), state)
        IOServiceClose(ioConnect)
    }

    public static func getCapsLockState() -> Bool {
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        IOServiceOpen(
            ioService,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &ioConnect
        )

        var modifierLockState = false
        IOHIDGetModifierLockState(
            ioConnect,
            Int32(kIOHIDCapsLockState),
            &modifierLockState
        )

        IOServiceClose(ioConnect)
        return modifierLockState
    }
}

// MARK: - HyperKey Class
class HyperKey {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var normalQuickPress: Bool
    private var includeShift: Bool
    private var lastKeyDown: Date?
    private var f18Down = false
    private var quickPressHandled = false
    private var capsLockManager = CapsLockManager()

    init(normalQuickPress: Bool, includeShift: Bool) {
        self.normalQuickPress = normalQuickPress
        self.includeShift = includeShift
        setupEventTap()
        mapCapsLockToF18()
        registerSignalHandlers()  // Register signal handlers
    }

    deinit {
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        resetKeyMapping()
    }

    // Source: https://medium.com/ryan-hanson/key-remapping-built-into-macos-c7953b1a62e4
    private func mapCapsLockToF18() {
        let mapping: [[String: Any]] = [
            [
                "HIDKeyboardModifierMappingSrc": 0x7_0000_0039,
                "HIDKeyboardModifierMappingDst": 0x7_0000_006D,
            ]
        ]
        executeHidutil(payload: ["UserKeyMapping": mapping])
    }

    func resetKeyMapping() {
        executeHidutil(payload: ["UserKeyMapping": []])
    }

    private func executeHidutil(payload: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: []
            ),
            let json = String(data: data, encoding: .utf8)
        else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", json]
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { NSLog("hidutil failed: \(error)") }
    }

    private func setupEventTap() {
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: { (proxy, type, event, ref) in
                    let obj = Unmanaged<HyperKey>.fromOpaque(ref!)
                        .takeUnretainedValue()
                    return obj.handleEvent(
                        proxy: proxy,
                        type: type,
                        event: event
                    )
                },
                userInfo: UnsafeMutableRawPointer(
                    Unmanaged.passUnretained(self).toOpaque()
                )
            )
        else {
            NSLog(
                "Failed to create event tap; enable Accessibility permissions."
            )
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        )
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(
        proxy: CGEventTapProxy?,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .keyDown || type == .keyUp {
            let code = UInt8(event.getIntegerValueField(.keyboardEventKeycode))
            if code == UInt8(kVK_F18) {
                if type == .keyDown {
                    f18Down = true
                    lastKeyDown = Date()
                    quickPressHandled = false
                } else {
                    f18Down = false
                    handleQuickPress()
                }
                return nil
            }
        }

        if f18Down {
            var mods: CGEventFlags = [
                .maskCommand, .maskControl, .maskAlternate,
            ]
            if includeShift { mods.insert(.maskShift) }
            event.flags = mods
            quickPressHandled = true
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleQuickPress() {
        guard normalQuickPress, let down = lastKeyDown else { return }
        if Date().timeIntervalSince(down) > 0.02 && !quickPressHandled {
            capsLockManager.toggleState()
            quickPressHandled = true
        }
    }

    // Register signal handlers for SIGINT, SIGTERM, and SIGQUIT
    private func registerSignalHandlers() {
        signal(SIGINT, handleSignal)
        signal(SIGTERM, handleSignal)
        signal(SIGQUIT, handleSignal)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hyperKey: HyperKey?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        var normalQuickPress = true
        var includeShift = false
        for arg in CommandLine.arguments.dropFirst() {
            if arg == "--no-quick-press" {
                normalQuickPress = false
            } else if arg == "--include-shift" {
                includeShift = true
            }
        }
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog(
                "Enable Accessibility in System Settings → Privacy → Accessibility"
            )
        }
        hyperKey = HyperKey(
            normalQuickPress: normalQuickPress,
            includeShift: includeShift
        )
        hyperKeyInstance = hyperKey  // Set global reference to the instance

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc func applicationWillTerminate(_ notification: Notification) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? proc.run()
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
