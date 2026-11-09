import AppKit
import KeyboardShortcuts
import Observation

@Observable
final class ShortcutAudit {
    static let shared = ShortcutAudit()

    private(set) var conflicts: Dictionary<KeyboardShortcuts.Name, String> = [:]

    @ObservationIgnored private var observers: Array<any NSObjectProtocol> = []

    private init() {}

    func start() {
        let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observers = [
            NotificationCenter.default.addObserver(
                forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"), object: nil, queue: .main, using: refresh),
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main, using: refresh),
        ]
        trackChanges { [weak self] in
            _ = Switcher.shared.sources
            _ = Preferences.shared.groups.map(\.name)
            self?.refresh()
        }
    }

    func conflict(for name: KeyboardShortcuts.Name) -> String? {
        conflicts[name]
    }

    func validate(_ shortcut: KeyboardShortcuts.Shortcut, for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.ValidationResult {
        guard let other = Self.names().first(where: { $0.name != name && KeyboardShortcuts.getShortcut(for: $0.name) == shortcut }) else {
            return .allow
        }
        return .disallow(reason: L.shortcutInUse(other.title))
    }

    func refresh() {
        let assigned = Self.names().compactMap { entry in KeyboardShortcuts.getShortcut(for: entry.name).map { (entry, $0) } }
        let system = Self.systemShortcuts()
        var result: Dictionary<KeyboardShortcuts.Name, String> = [:]
        for (entry, shortcut) in assigned {
            if let other = assigned.first(where: { $0.0.name != entry.name && $0.1 == shortcut }) {
                result[entry.name] = L.conflictSegue(other.0.title)
            } else if let title = system.first(where: { $0.shortcut == shortcut })?.title {
                result[entry.name] = L.conflictSystem(title)
            }
        }
        if result != conflicts { conflicts = result }
    }

    static func names() -> Array<(name: KeyboardShortcuts.Name, title: String)> {
        var names: Array<(name: KeyboardShortcuts.Name, title: String)> = [(.quickSwitcher, L.quickSwitcherTitle)]
        for source in Switcher.shared.sources { names.append((.source(source.id), source.name)) }
        for group in Preferences.shared.groups { names.append((.group(group.id), group.name)) }
        return names
    }

    private struct SystemShortcut {
        let id: String
        let title: String
        let modifiers: NSEvent.ModifierFlags
    }

    private static func systemShortcuts() -> Array<(shortcut: KeyboardShortcuts.Shortcut, title: String)> {
        let hotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        let known = [
            SystemShortcut(id: "60", title: L.systemPreviousSource, modifiers: [.control]),
            SystemShortcut(id: "61", title: L.systemNextSource, modifiers: [.control, .option]),
        ]
        return known.compactMap { entry in
            guard let stored = hotKeys[entry.id] as? Dictionary<String, Any> else {
                return (KeyboardShortcuts.Shortcut(.space, modifiers: entry.modifiers), entry.title)
            }
            guard stored["enabled"] as? Bool == true, let value = stored["value"] as? Dictionary<String, Any>,
                let parameters = value["parameters"] as? Array<Int>, parameters.count == 3
            else { return nil }
            let shortcut = KeyboardShortcuts.Shortcut(
                KeyboardShortcuts.Key(rawValue: parameters[1]), modifiers: NSEvent.ModifierFlags(rawValue: UInt(parameters[2])))
            return (shortcut, entry.title)
        }
    }
}
