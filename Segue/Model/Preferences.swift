import Foundation
import Observation

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case label
    case icon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .label: L.menuBarStyleLabel
        case .icon: L.menuBarStyleIcon
        }
    }
}

enum IndicatorMode: String, CaseIterable, Identifiable {
    case never
    case segue
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: L.indicatorNever
        case .segue: L.indicatorSegue
        case .always: L.indicatorAlways
        }
    }
}

enum IndicatorPosition: String, CaseIterable, Identifiable {
    case topRight
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topRight: L.positionTopRight
        case .center: L.positionCenter
        case .bottom: L.positionBottom
        }
    }
}

struct SourceGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sourceIDs: Array<String> = []
}

struct AppRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleID: String
    var sourceID: String
}

struct WebsiteRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var domain: String
    var sourceID: String

    var normalizedDomain: String {
        var value = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = value.range(of: "://") { value = String(value[range.upperBound...]) }
        if let slash = value.firstIndex(where: { "/?#:".contains($0) }) { value = String(value[..<slash]) }
        if value.hasPrefix("www.") { value = String(value.dropFirst(4)) }
        return value
    }

    func matches(_ host: String) -> Bool {
        let domain = normalizedDomain
        guard !domain.isEmpty else { return false }
        let host = host.lowercased()
        return host == domain || host.hasSuffix("." + domain)
    }
}

enum ModifierKey: String, Codable, CaseIterable, Identifiable {
    case leftCommand
    case rightCommand
    case leftOption
    case rightOption
    case leftControl
    case rightControl
    case leftShift
    case rightShift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftCommand: L.keyLeftCommand
        case .rightCommand: L.keyRightCommand
        case .leftOption: L.keyLeftOption
        case .rightOption: L.keyRightOption
        case .leftControl: L.keyLeftControl
        case .rightControl: L.keyRightControl
        case .leftShift: L.keyLeftShift
        case .rightShift: L.keyRightShift
        }
    }
}

enum TapGesture: String, Codable, CaseIterable, Identifiable {
    case tap
    case doubleTap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: L.gestureTap
        case .doubleTap: L.gestureDoubleTap
        }
    }
}

enum TriggerTarget: Codable, Hashable {
    case source(String)
    case group(UUID)
    case quickSwitcher
}

struct ModifierTrigger: Codable, Identifiable, Hashable {
    var id = UUID()
    var key: ModifierKey
    var gesture: TapGesture
    var target: TriggerTarget
}

@Observable
final class Preferences {
    static let shared = Preferences()

    static let store = DemoData.isEnabled ? DemoData.defaults : .standard

    @ObservationIgnored private let defaults = Preferences.store
    @ObservationIgnored private var loading = false

    var showInMenuBar = true { didSet { store(showInMenuBar, "showInMenuBar") } }
    var showInDock = true { didSet { store(showInDock, "showInDock") } }
    var menuBarStyle = MenuBarStyle.label { didSet { store(menuBarStyle.rawValue, "menuBarStyle") } }
    var indicatorMode = IndicatorMode.segue { didSet { store(indicatorMode.rawValue, "indicatorMode") } }
    var indicatorPosition = IndicatorPosition.topRight { didSet { store(indicatorPosition.rawValue, "indicatorPosition") } }
    var labels: Dictionary<String, String> = [:] { didSet { encode(labels, "labels") } }
    var groups: Array<SourceGroup> = [] { didSet { encode(groups, "groups") } }
    var rememberAppSources = false { didSet { store(rememberAppSources, "rememberAppSources") } }
    var appRules: Array<AppRule> = [] { didSet { encode(appRules, "appRules") } }
    var websiteRules: Array<WebsiteRule> = [] { didSet { encode(websiteRules, "websiteRules") } }
    var appMemory: Dictionary<String, String> = [:] { didSet { encode(appMemory, "appMemory") } }
    var modifierTriggers: Array<ModifierTrigger> = [] { didSet { encode(modifierTriggers, "modifierTriggers") } }

    private init() {
        loading = true
        let d = defaults
        showInMenuBar = d.object(forKey: "showInMenuBar") as? Bool ?? true
        showInDock = d.object(forKey: "showInDock") as? Bool ?? true
        menuBarStyle = d.string(forKey: "menuBarStyle").flatMap(MenuBarStyle.init(rawValue:)) ?? .label
        indicatorMode = d.string(forKey: "indicatorMode").flatMap(IndicatorMode.init(rawValue:)) ?? .segue
        indicatorPosition = d.string(forKey: "indicatorPosition").flatMap(IndicatorPosition.init(rawValue:)) ?? .topRight
        labels = Self.decode(Dictionary<String, String>.self, d, "labels") ?? [:]
        groups = Self.decode(Array<SourceGroup>.self, d, "groups") ?? []
        rememberAppSources = d.bool(forKey: "rememberAppSources")
        appRules = Self.decode(Array<AppRule>.self, d, "appRules") ?? []
        websiteRules = Self.decode(Array<WebsiteRule>.self, d, "websiteRules") ?? []
        appMemory = Self.decode(Dictionary<String, String>.self, d, "appMemory") ?? [:]
        modifierTriggers = Self.decode(Array<ModifierTrigger>.self, d, "modifierTriggers") ?? []
        loading = false
        if DemoData.isEnabled { DemoData.seed(self) }
    }

    func label(for source: InputSource) -> String {
        let custom = labels[source.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? source.defaultLabel : custom
    }

    func group(_ id: UUID) -> SourceGroup? {
        groups.first { $0.id == id }
    }

    func group(matching query: String) -> SourceGroup? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return groups.first { $0.id.uuidString.caseInsensitiveCompare(query) == .orderedSame }
            ?? groups.first { $0.name.caseInsensitiveCompare(query) == .orderedSame }
            ?? groups.first { $0.name.localizedStandardContains(query) }
    }

    @discardableResult
    func addGroup() -> SourceGroup {
        let group = SourceGroup(name: L.groupDefaultName(groups.count + 1))
        groups.append(group)
        return group
    }

    func removeGroup(_ id: UUID) {
        groups.removeAll { $0.id == id }
        modifierTriggers.removeAll { $0.target == .group(id) }
    }

    private func store(_ value: Any, _ key: String) {
        guard !loading else { return }
        defaults.set(value, forKey: key)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        guard !loading, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
