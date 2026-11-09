import AppIntents
import Foundation

nonisolated enum SegueIntentError: Error, CustomLocalizedStringResourceConvertible {
    case sourceMissing
    case groupEmpty

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .sourceMissing: "That input source isn't turned on. Turn it on in System Settings > Keyboard > Text Input."
        case .groupEmpty: "That group needs at least two input sources."
        }
    }
}

nonisolated struct InputSourceEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Input Source"
    static let defaultQuery = InputSourceQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

nonisolated struct InputSourceQuery: EntityStringQuery {
    func entities(for identifiers: Array<String>) async -> Array<InputSourceEntity> {
        await IntentSupport.sources().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async -> Array<InputSourceEntity> {
        await IntentSupport.sources().filter { $0.name.localizedStandardContains(string) }
    }

    func suggestedEntities() async -> Array<InputSourceEntity> {
        await IntentSupport.sources()
    }
}

nonisolated struct SourceGroupEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Input Source Group"
    static let defaultQuery = SourceGroupQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

nonisolated struct SourceGroupQuery: EntityQuery {
    func entities(for identifiers: Array<UUID>) async -> Array<SourceGroupEntity> {
        await IntentSupport.groups().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async -> Array<SourceGroupEntity> {
        await IntentSupport.groups()
    }
}

struct SwitchInputSourceIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Input Source"
    static let description: IntentDescription? = IntentDescription("Switches to the input source you choose.")

    @Parameter(title: "Input Source") var source: InputSourceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Switch to \(\.$source)")
    }

    init() {}

    init(source: InputSourceEntity) {
        self.source = source
    }

    @MainActor func perform() throws -> some IntentResult {
        try IntentSupport.select(source.id)
        return .result()
    }
}

struct CycleSourceGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Cycle Input Source Group"
    static let description: IntentDescription? = IntentDescription("Switches to the next input source in a group.")

    @Parameter(title: "Input Source Group") var group: SourceGroupEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Cycle \(\.$group)")
    }

    @MainActor func perform() throws -> some IntentResult {
        try IntentSupport.cycle(group.id)
        return .result()
    }
}

struct CurrentInputSourceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Input Source"
    static let description: IntentDescription? = IntentDescription("Returns the input source you're typing with.")

    @MainActor func perform() throws -> some IntentResult & ReturnsValue<InputSourceEntity> {
        guard let current = IntentSupport.current() else { throw SegueIntentError.sourceMissing }
        return .result(value: current)
    }
}

nonisolated struct SegueShortcuts: AppShortcutsProvider {
    static var appShortcuts: Array<AppShortcut> {
        AppShortcut(
            intent: SwitchInputSourceIntent(),
            phrases: [
                "Switch input source with \(.applicationName)",
                "Switch to \(\.$source) with \(.applicationName)",
            ],
            shortTitle: "Switch Input Source",
            systemImageName: "keyboard")
        AppShortcut(
            intent: CycleSourceGroupIntent(),
            phrases: [
                "Cycle input sources with \(.applicationName)",
                "Cycle \(\.$group) with \(.applicationName)",
            ],
            shortTitle: "Cycle Input Source Group",
            systemImageName: "square.stack")
        AppShortcut(
            intent: CurrentInputSourceIntent(),
            phrases: ["Get the current input source in \(.applicationName)"],
            shortTitle: "Get Current Input Source",
            systemImageName: "keyboard.badge.eye")
    }
}

enum IntentSupport {
    static func sources() -> Array<InputSourceEntity> {
        Switcher.shared.sources.map(entity)
    }

    static func groups() -> Array<SourceGroupEntity> {
        Preferences.shared.groups.map { SourceGroupEntity(id: $0.id, name: $0.name) }
    }

    static func current() -> InputSourceEntity? {
        Switcher.shared.current.map(entity)
    }

    static func select(_ id: String) throws {
        guard let source = Switcher.shared.source(id) else { throw SegueIntentError.sourceMissing }
        Switcher.shared.select(source)
    }

    static func cycle(_ id: UUID) throws {
        guard let group = Preferences.shared.group(id), group.sourceIDs.compactMap(Switcher.shared.source).count >= 2 else {
            throw SegueIntentError.groupEmpty
        }
        Switcher.shared.cycle(id)
    }

    static func sourcesDidChange() {
        SegueShortcuts.updateAppShortcutParameters()
    }

    private static func entity(_ source: InputSource) -> InputSourceEntity {
        InputSourceEntity(id: source.id, name: source.name)
    }
}
