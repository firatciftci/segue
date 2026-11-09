import AppKit
import Carbon
import KeyboardShortcuts

enum KawaImporter {
    private static let domain = "net.noraesae.Kawa"

    static func shortcuts() -> Dictionary<String, KeyboardShortcuts.Shortcut> {
        guard let defaults = UserDefaults(suiteName: domain) else { return [:] }
        var result: Dictionary<String, KeyboardShortcuts.Shortcut> = [:]
        for id in InputSource.installedIDs() {
            let key = id.replacingOccurrences(of: ".", with: "-")
            guard let data = defaults.data(forKey: key), let legacy = decode(data) else { continue }
            result[id] = KeyboardShortcuts.Shortcut(
                KeyboardShortcuts.Key(rawValue: legacy.keyCode), modifiers: NSEvent.ModifierFlags(rawValue: legacy.modifierFlags))
        }
        return result
    }

    static func importShortcuts() -> Int {
        let found = shortcuts()
        for (id, shortcut) in found {
            KeyboardShortcuts.setShortcut(shortcut, for: .source(id))
        }
        return found.count
    }

    private static func decode(_ data: Data) -> LegacyShortcut? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.setClass(LegacyShortcut.self, forClassName: "MASShortcut")
        defer { unarchiver.finishDecoding() }
        return unarchiver.decodeObject(of: LegacyShortcut.self, forKey: NSKeyedArchiveRootObjectKey)
    }
}

@objc(SegueLegacyShortcut)
nonisolated private final class LegacyShortcut: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let keyCode: Int
    let modifierFlags: UInt

    init?(coder: NSCoder) {
        keyCode = coder.decodeInteger(forKey: "KeyCode")
        modifierFlags = UInt(clamping: coder.decodeInteger(forKey: "ModifierFlags"))
    }

    func encode(with coder: NSCoder) {
        coder.encode(keyCode, forKey: "KeyCode")
        coder.encode(Int(modifierFlags), forKey: "ModifierFlags")
    }
}

extension InputSource {
    static func installedIDs() -> Array<String> {
        references(includeAllInstalled: true).compactMap { $0.string(kTISPropertyInputSourceID) }
    }
}
