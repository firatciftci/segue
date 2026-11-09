import AppKit
import Observation

@Observable
final class ModifierTaps {
    static let shared = ModifierTaps()

    private(set) var isAuthorized = DemoData.isEnabled || CGPreflightListenEventAccess()

    @ObservationIgnored private let prefs = Preferences.shared
    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var pressed: (key: ModifierKey, time: TimeInterval)?
    @ObservationIgnored private var lastTap: (key: ModifierKey, time: TimeInterval)?
    @ObservationIgnored private var pendingTap: Task<Void, Never>?

    private static let maximumHold: TimeInterval = 0.35
    private static let doubleTapWindow: TimeInterval = 0.3

    private init() {}

    func start() {
        trackChanges { [weak self] in
            guard let self else { return }
            _ = self.prefs.modifierTriggers
            self.update()
        }
    }

    func requestAccess() {
        isAuthorized = CGRequestListenEventAccess()
        if !isAuthorized {
            PrivacySettings.open(.inputMonitoring)
        }
        update()
    }

    func refreshAuthorization() {
        let authorized = DemoData.isEnabled || CGPreflightListenEventAccess()
        if authorized != isAuthorized { isAuthorized = authorized }
        update()
    }

    private func update() {
        let needed = !prefs.modifierTriggers.isEmpty && isAuthorized
        if needed, tap == nil {
            install()
        } else if !needed, let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            self.tap = nil
            source = nil
        }
    }

    private func install() {
        let types: Array<CGEventType> = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        var mask: CGEventMask = 0
        for type in types { mask |= 1 << type.rawValue }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
                callback: modifierTapCallback, userInfo: nil)
        else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    func handle(_ type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            flagsChanged(keyCode: keyCode, flags: flags)
        default:
            pressed = nil
            lastTap = nil
        }
    }

    private func flagsChanged(keyCode: Int64, flags: CGEventFlags) {
        let now = ProcessInfo.processInfo.systemUptime
        guard let key = ModifierKey(keyCode: keyCode) else {
            pressed = nil
            return
        }
        if key.isDown(in: flags) {
            pressed = flags.intersection(ModifierKey.relevantFlags) == key.flag ? (key, now) : nil
            return
        }
        guard let pressed, pressed.key == key, now - pressed.time <= Self.maximumHold,
            flags.isDisjoint(with: ModifierKey.relevantFlags)
        else {
            self.pressed = nil
            return
        }
        self.pressed = nil
        tapped(key, at: now)
    }

    private func tapped(_ key: ModifierKey, at time: TimeInterval) {
        let triggers = prefs.modifierTriggers.filter { $0.key == key }
        let single = triggers.first { $0.gesture == .tap }
        let double = triggers.first { $0.gesture == .doubleTap }
        if let lastTap, lastTap.key == key, time - lastTap.time <= Self.doubleTapWindow, let double {
            self.lastTap = nil
            pendingTap?.cancel()
            Switcher.shared.perform(double.target)
            return
        }
        lastTap = (key, time)
        guard let single else { return }
        guard double != nil else {
            Switcher.shared.perform(single.target)
            return
        }
        pendingTap?.cancel()
        pendingTap = Task {
            try? await Task.sleep(for: .seconds(Self.doubleTapWindow))
            guard !Task.isCancelled else { return }
            Switcher.shared.perform(single.target)
        }
    }
}

private nonisolated func modifierTapCallback(
    _: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    MainActor.assumeIsolated { ModifierTaps.shared.handle(type, keyCode: keyCode, flags: flags) }
    return Unmanaged.passUnretained(event)
}

extension ModifierKey {
    static let relevantFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    init?(keyCode: Int64) {
        switch keyCode {
        case 55: self = .leftCommand
        case 54: self = .rightCommand
        case 58: self = .leftOption
        case 61: self = .rightOption
        case 59: self = .leftControl
        case 62: self = .rightControl
        case 56: self = .leftShift
        case 60: self = .rightShift
        default: return nil
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .leftCommand, .rightCommand: .maskCommand
        case .leftOption, .rightOption: .maskAlternate
        case .leftControl, .rightControl: .maskControl
        case .leftShift, .rightShift: .maskShift
        }
    }

    private var deviceFlag: UInt64 {
        switch self {
        case .leftControl: 0x0000_0001
        case .leftShift: 0x0000_0002
        case .rightShift: 0x0000_0004
        case .leftCommand: 0x0000_0008
        case .rightCommand: 0x0000_0010
        case .leftOption: 0x0000_0020
        case .rightOption: 0x0000_0040
        case .rightControl: 0x0000_2000
        }
    }

    func isDown(in flags: CGEventFlags) -> Bool {
        flags.rawValue & deviceFlag != 0
    }
}

enum PrivacySettings {
    enum Pane: String {
        case inputMonitoring = "Privacy_ListenEvent"
        case automation = "Privacy_Automation"
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else { return }
        NSWorkspace.shared.open(url)
    }
}
