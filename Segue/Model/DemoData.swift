import AppKit
import KeyboardShortcuts

enum DemoData {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demo")

    static let appearance: NSAppearance.Name? = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-dark") { return .darkAqua }
        if arguments.contains("-light") { return .aqua }
        return nil
    }()

    static let defaults: UserDefaults = {
        let name = "com.firatciftci.Segue.demo"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        defaults.set(true, forKey: "hasLaunched")
        return defaults
    }()

    private static let english = "com.apple.keylayout.US"
    private static let turkish = "com.apple.keylayout.Turkish-QWERTY-PC"
    private static let german = "com.apple.keylayout.German"
    private static let greek = "com.apple.keylayout.Greek"
    private static let arabic = "com.apple.keylayout.Arabic"
    private static let japanese = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

    static func sources() -> Array<InputSource> {
        let installed = InputSource.references(includeAllInstalled: true).compactMap(InputSource.init)
        return [english, turkish, german, greek, arabic, japanese].compactMap { id in installed.first { $0.id == id } }
    }

    static func seed(_ prefs: Preferences) {
        let everyday = SourceGroup(name: "Everyday", sourceIDs: [english, turkish, german])
        let languages = SourceGroup(name: "Languages", sourceIDs: [greek, arabic, japanese])
        prefs.labels = [japanese: "JP"]
        prefs.groups = [everyday, languages]
        prefs.rememberAppSources = true
        prefs.appRules = [
            AppRule(bundleID: "com.apple.Terminal", sourceID: english),
            AppRule(bundleID: "com.apple.MobileSMS", sourceID: turkish),
            AppRule(bundleID: "com.apple.mail", sourceID: german),
            AppRule(bundleID: "com.apple.Notes", sourceID: japanese),
        ]
        prefs.websiteRules = [
            WebsiteRule(domain: "github.com", sourceID: english),
            WebsiteRule(domain: "spiegel.de", sourceID: german),
            WebsiteRule(domain: "nhk.or.jp", sourceID: japanese),
        ]
        prefs.modifierTriggers = [
            ModifierTrigger(key: .rightCommand, gesture: .doubleTap, target: .quickSwitcher),
            ModifierTrigger(key: .rightOption, gesture: .tap, target: .group(everyday.id)),
            ModifierTrigger(key: .rightShift, gesture: .doubleTap, target: .group(languages.id)),
        ]
        let shortcuts: Array<(KeyboardShortcuts.Name, KeyboardShortcuts.Shortcut)> = [
            (.source(english), .init(.one, modifiers: [.control, .option])),
            (.source(turkish), .init(.two, modifiers: [.control, .option])),
            (.source(german), .init(.three, modifiers: [.control, .option])),
            (.source(greek), .init(.four, modifiers: [.control, .option])),
            (.source(arabic), .init(.five, modifiers: [.control, .option])),
            (.source(japanese), .init(.six, modifiers: [.control, .option])),
            (.group(everyday.id), .init(.e, modifiers: [.control, .option])),
            (.group(languages.id), .init(.l, modifiers: [.control, .option])),
            (.quickSwitcher, .init(.space, modifiers: [.control, .option])),
        ]
        let standard = UserDefaults.standard
        var arguments = standard.volatileDomain(forName: UserDefaults.argumentDomain)
        for (name, shortcut) in shortcuts {
            guard let data = try? JSONEncoder().encode(shortcut), let value = String(bytes: data, encoding: .utf8) else { continue }
            arguments["KeyboardShortcuts_\(name.rawValue)"] = value
        }
        standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
