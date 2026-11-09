import AppKit
import Carbon

struct InputSource: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: NSImage
    let defaultLabel: String
    let languageName: String?
    private let reference: TISInputSource
    private let order: String

    init?(_ reference: TISInputSource) {
        guard reference.string(kTISPropertyInputSourceCategory) == kTISCategoryKeyboardInputSource as String,
            reference.bool(kTISPropertyInputSourceIsSelectCapable),
            let id = reference.string(kTISPropertyInputSourceID)
        else { return nil }
        let name = reference.string(kTISPropertyLocalizedName) ?? id
        self.id = id
        self.name = name
        self.reference = reference
        let language = reference.strings(kTISPropertyInputSourceLanguages).first.map { Locale.Language(identifier: $0) }
        icon =
            id.hasPrefix("com.apple.keylayout.")
            ? SourceTile.image(script: language?.script, name: name)
            : reference.icon ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: name) ?? NSImage()
        defaultLabel = language?.languageCode?.identifier.uppercased() ?? String(name.prefix(2)).uppercased()
        languageName = language?.languageCode.flatMap { Locale.current.localizedString(forLanguageCode: $0.identifier) }
        order = [languageName == nil ? "1" : "0", languageName ?? name, id].joined(separator: "\u{0}")
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func select() {
        TISSelectInputSource(reference)
    }

    static func enabled() -> Array<Self> {
        list(includeAllInstalled: false).sorted { $0.order.localizedStandardCompare($1.order) == .orderedAscending }
    }

    static func matching(_ query: String, in sources: Array<Self>, labels: Dictionary<String, String>) -> Self? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        func same(_ value: String?) -> Bool {
            value?.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        func unique(_ matches: Array<Self>) -> Self? { matches.count == 1 ? matches.first : nil }
        return sources.first { $0.id == query }
            ?? sources.first { same(labels[$0.id]) }
            ?? sources.first { same($0.defaultLabel) }
            ?? sources.first { same($0.name) }
            ?? unique(sources.filter { $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil })
            ?? unique(sources.filter { $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query) })
    }

    static func current() -> Self? {
        Self(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
    }

    private static func list(includeAllInstalled: Bool) -> Array<Self> {
        references(includeAllInstalled: includeAllInstalled).compactMap(Self.init)
    }

    static func references(includeAllInstalled: Bool) -> Array<TISInputSource> {
        TISCreateInputSourceList(nil, includeAllInstalled)?.takeRetainedValue() as? Array<TISInputSource> ?? []
    }
}

extension TISInputSource {
    func value(_ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(self, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    func string(_ key: CFString) -> String? {
        value(key) as? String
    }

    func strings(_ key: CFString) -> Array<String> {
        value(key) as? Array<String> ?? []
    }

    func bool(_ key: CFString) -> Bool {
        value(key) as? Bool ?? false
    }

    var icon: NSImage? {
        if let url = value(kTISPropertyIconImageURL) as? URL {
            let retina = url.deletingLastPathComponent()
                .appendingPathComponent(url.deletingPathExtension().lastPathComponent + "@2x")
                .appendingPathExtension(url.pathExtension)
            for candidate in [retina, url.deletingPathExtension().appendingPathExtension("tiff"), url] {
                guard let image = NSImage(contentsOf: candidate) else { continue }
                if image.isBlackMask { image.isTemplate = true }
                return image
            }
        }
        guard let pointer = TISGetInputSourceProperty(self, kTISPropertyIconRef) else { return nil }
        let converter: any IconRefConverting = LegacyIconRefConverter()
        return converter.image(from: OpaquePointer(pointer))
    }
}

extension NSImage {
    var isBlackMask: Bool {
        guard let bitmap = representations.lazy.compactMap({ $0 as? NSBitmapImageRep }).first else { return false }
        var hasInk = false
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.05 else { continue }
                guard max(color.redComponent, color.greenComponent, color.blueComponent) < 0.1 else { return false }
                hasInk = true
            }
        }
        return hasInk
    }
}

private protocol IconRefConverting {
    func image(from reference: IconRef) -> NSImage
}

private struct LegacyIconRefConverter: IconRefConverting {
    @available(macOS, deprecated: 11.0)
    func image(from reference: IconRef) -> NSImage {
        NSImage(iconRef: reference)
    }
}

private enum SourceTile {
    static func image(script: Locale.Script?, name: String) -> NSImage {
        let glyphs: Dictionary<String, String> = [
            "Cyrl": "Б", "Grek": "Ω", "Arab": "ع", "Hebr": "א", "Armn": "Ա", "Geor": "ა", "Deva": "अ", "Beng": "অ",
            "Thai": "ก", "Hang": "가", "Hans": "文", "Hant": "文", "Jpan": "あ", "Ethi": "አ", "Tibt": "ཀ",
        ]
        let glyph = script.flatMap { glyphs[$0.identifier] } ?? "A"
        let font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        let string = NSAttributedString(string: glyph, attributes: [.font: font, .foregroundColor: NSColor.black])
        let textSize = string.size()
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            string.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = name
        return image
    }
}
