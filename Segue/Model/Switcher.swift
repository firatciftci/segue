import Carbon
import KeyboardShortcuts
import Observation

extension KeyboardShortcuts.Name {
    static func source(_ id: String) -> Self { Self("source.\(id)") }
    static func group(_ id: UUID) -> Self { Self("group.\(id.uuidString)") }
    static let quickSwitcher = Self("quickSwitcher")
}

@Observable
final class Switcher {
    static let shared = Switcher()

    private(set) var sources: Array<InputSource> = []
    private(set) var current: InputSource?
    private(set) var previous: InputSource?

    @ObservationIgnored private let prefs = Preferences.shared
    @ObservationIgnored private var expectedID: String?
    @ObservationIgnored private var registered: Set<KeyboardShortcuts.Name> = []
    @ObservationIgnored private var lastUsed: Dictionary<UUID, String> = [:]
    @ObservationIgnored private var observers: Array<any NSObjectProtocol> = []

    private init() {}

    func start() {
        if DemoData.isEnabled {
            sources = DemoData.sources()
            current = sources.first
            registerShortcuts()
            return
        }
        reload()
        let center = DistributedNotificationCenter.default()
        let selected = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        let enabled = Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)
        observers.append(
            center.addObserver(forName: selected, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.selectionDidChange() }
            })
        observers.append(
            center.addObserver(forName: enabled, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            })
    }

    func source(_ id: String) -> InputSource? {
        sources.first { $0.id == id }
    }

    func select(_ source: InputSource, detail: String? = nil, showsIndicator: Bool = true) {
        if source != current, !DemoData.isEnabled {
            expectedID = source.id
            source.select()
        }
        didSelect(source)
        if showsIndicator, prefs.indicatorMode != .never {
            Indicator.shared.show(source, detail: detail)
        }
        Feedback.announce(source.name)
    }

    func cycle(_ groupID: UUID) {
        guard let group = prefs.group(groupID) else { return }
        let members = group.sourceIDs.compactMap(source)
        guard let first = members.first else { return }
        let target: InputSource
        if let current, let index = members.firstIndex(of: current) {
            target = members[(index + 1) % members.count]
        } else {
            target = members.first { $0.id == lastUsed[groupID] } ?? first
        }
        select(target, detail: group.name)
    }

    @discardableResult
    func addGroup() -> SourceGroup {
        let group = prefs.addGroup()
        registerShortcuts()
        return group
    }

    func removeGroup(_ id: UUID) {
        let name = KeyboardShortcuts.Name.group(id)
        KeyboardShortcuts.reset(name)
        KeyboardShortcuts.removeHandler(for: name)
        registered.remove(name)
        lastUsed[id] = nil
        prefs.removeGroup(id)
    }

    func reloadShortcuts() {
        registerShortcuts()
    }

    private func reload() {
        sources = InputSource.enabled()
        current = InputSource.current()
        registerShortcuts()
        IntentSupport.sourcesDidChange()
    }

    private func selectionDidChange() {
        guard let source = InputSource.current() else { return }
        let initiatedHere = expectedID == source.id
        expectedID = nil
        didSelect(source)
        if !initiatedHere, prefs.indicatorMode == .always {
            Indicator.shared.show(source, detail: nil)
        }
    }

    private func didSelect(_ source: InputSource) {
        if source != current { previous = current }
        current = source
        AutoSwitcher.shared.sourceDidChange(source)
        for group in prefs.groups where group.sourceIDs.contains(source.id) {
            lastUsed[group.id] = source.id
        }
    }

    private func registerShortcuts() {
        for source in sources {
            let id = source.id
            register(.source(id)) { [weak self] in
                guard let self, let source = self.source(id) else { return }
                self.select(source)
            }
        }
        for group in prefs.groups {
            let id = group.id
            register(.group(id)) { [weak self] in self?.cycle(id) }
        }
        register(.quickSwitcher) { QuickSwitcher.shared.toggle() }
    }

    func perform(_ target: TriggerTarget) {
        switch target {
        case .source(let id):
            if let source = source(id) { select(source) }
        case .group(let id): cycle(id)
        case .quickSwitcher: QuickSwitcher.shared.toggle()
        }
    }

    private func register(_ name: KeyboardShortcuts.Name, action: @escaping () -> Void) {
        guard !registered.contains(name) else { return }
        registered.insert(name)
        KeyboardShortcuts.onKeyDown(for: name, action: action)
    }
}
