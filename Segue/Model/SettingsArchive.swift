import AppKit
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsArchive: Codable {
    private static let formatVersion = 1

    var version = Self.formatVersion
    var showInMenuBar: Bool
    var showInDock: Bool
    var menuBarStyle: String
    var indicatorMode: String
    var indicatorPosition: String
    var labels: Dictionary<String, String>
    var groups: Array<SourceGroup>
    var rememberAppSources: Bool
    var appRules: Array<AppRule>
    var websiteRules: Array<WebsiteRule>
    var modifierTriggers: Array<ModifierTrigger>
    var shortcuts: Dictionary<String, KeyboardShortcuts.Shortcut>

    private static let shortcutPrefixes = ["source.", "group.", KeyboardShortcuts.Name.quickSwitcher.rawValue]

    static func current() -> Self {
        let prefs = Preferences.shared
        var shortcuts: Dictionary<String, KeyboardShortcuts.Shortcut> = [:]
        for name in names(prefs) {
            if let shortcut = KeyboardShortcuts.getShortcut(for: name) { shortcuts[name.rawValue] = shortcut }
        }
        return Self(
            showInMenuBar: prefs.showInMenuBar, showInDock: prefs.showInDock, menuBarStyle: prefs.menuBarStyle.rawValue,
            indicatorMode: prefs.indicatorMode.rawValue,
            indicatorPosition: prefs.indicatorPosition.rawValue, labels: prefs.labels, groups: prefs.groups,
            rememberAppSources: prefs.rememberAppSources, appRules: prefs.appRules, websiteRules: prefs.websiteRules,
            modifierTriggers: prefs.modifierTriggers, shortcuts: shortcuts)
    }

    func apply() {
        let prefs = Preferences.shared
        for name in Self.names(prefs) { KeyboardShortcuts.reset(name) }
        prefs.showInMenuBar = showInMenuBar
        prefs.showInDock = showInDock
        prefs.menuBarStyle = MenuBarStyle(rawValue: menuBarStyle) ?? prefs.menuBarStyle
        prefs.indicatorMode = IndicatorMode(rawValue: indicatorMode) ?? prefs.indicatorMode
        prefs.indicatorPosition = IndicatorPosition(rawValue: indicatorPosition) ?? prefs.indicatorPosition
        prefs.labels = labels
        prefs.groups = groups
        prefs.rememberAppSources = rememberAppSources
        prefs.appRules = appRules
        prefs.websiteRules = websiteRules
        prefs.modifierTriggers = modifierTriggers
        for (raw, shortcut) in shortcuts where Self.shortcutPrefixes.contains(where: raw.hasPrefix) {
            KeyboardShortcuts.setShortcut(shortcut, for: KeyboardShortcuts.Name(raw))
        }
        Switcher.shared.reloadShortcuts()
        AutoSwitcher.shared.rulesDidChange()
    }

    private static func names(_ prefs: Preferences) -> Array<KeyboardShortcuts.Name> {
        var names: Array<KeyboardShortcuts.Name> = [.quickSwitcher]
        names += InputSource.installedIDs().map(KeyboardShortcuts.Name.source)
        names += prefs.groups.map { KeyboardShortcuts.Name.group($0.id) }
        return names
    }

    static func export() async -> URL? {
        let window = NSApp.keyWindow
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = L.exportFileName
        panel.canCreateDirectories = true
        guard await run(panel, in: window) == .OK, let url = panel.url else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(current()).write(to: url, options: .atomic)
            return url
        } catch {
            await Feedback.alert(L.exportFailedTitle, error.localizedDescription, in: window)
            return nil
        }
    }

    static func importFile() async -> URL? {
        let window = NSApp.keyWindow
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard await run(panel, in: window) == .OK, let url = panel.url else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            await Feedback.alert(L.importFailedTitle, error.localizedDescription, in: window)
            return nil
        }
        guard let archive = try? JSONDecoder().decode(Self.self, from: data) else {
            await Feedback.alert(L.importFailedTitle, L.importFailed, in: window)
            return nil
        }
        guard archive.version <= Self.formatVersion else {
            await Feedback.alert(L.importFailedTitle, L.importNewer, in: window)
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path)
        guard await Feedback.confirm(L.importConfirmTitle, L.importConfirmMessage(name), action: L.importConfirmButton, in: window)
        else { return nil }
        archive.apply()
        return url
    }

    private static func run(_ panel: NSSavePanel, in window: NSWindow?) async -> NSApplication.ModalResponse {
        guard let window else { return panel.runModal() }
        return await panel.beginSheetModal(for: window)
    }
}
