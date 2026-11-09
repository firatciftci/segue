import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@Observable
private final class SwitcherModel {
    var query = ""
    var selection = 0

    var results: Array<InputSource> {
        let sources = Switcher.shared.sources
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sources }
        let prefs = Preferences.shared
        func rank(_ source: InputSource) -> Int? {
            let label = prefs.label(for: source)
            if label.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { return 0 }
            if source.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil { return 1 }
            if source.name.localizedStandardContains(query) || label.localizedStandardContains(query) { return 2 }
            if source.languageName?.localizedStandardContains(query) == true || source.id.localizedStandardContains(query) { return 3 }
            return nil
        }
        return sources.compactMap { source in rank(source).map { (source, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}

private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    @objc func hasKeyAppearance() -> Bool { true }
}

final class QuickSwitcher: NSObject, NSWindowDelegate {
    static let shared = QuickSwitcher()

    private static let width: CGFloat = 480
    private static let rowHeight: CGFloat = 44
    private static let headerHeight: CGFloat = 60
    private static let maximumRows = 8
    private static let digitKeyCodes: Array<UInt16> = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    private let model = SwitcherModel()
    private let panel: SwitcherPanel
    private var monitor: Any?

    override private init() {
        panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: QuickSwitcherView(model: model, rowHeight: Self.rowHeight, headerHeight: Self.headerHeight, choose: choose)
                .environment(Preferences.shared))
        trackChanges { [weak self] in
            guard let self else { return }
            _ = self.model.results.count
            self.layout()
        }
    }

    func toggle() {
        if panel.isVisible {
            move(by: 1)
        } else {
            show()
        }
    }

    func show() {
        guard !panel.isVisible else { return }
        model.query = ""
        let sources = model.results
        let switcher = Switcher.shared
        let preferred = switcher.previous.flatMap(sources.firstIndex(of:))
        let current = switcher.current.flatMap(sources.firstIndex(of:))
        model.selection = preferred ?? current.map { ($0 + 1) % max(sources.count, 1) } ?? 0
        layout(recenter: true)
        panel.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
        announceSelection()
    }

    func hide() {
        guard panel.isVisible else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel.orderOut(nil)
    }

    func windowDidResignKey(_: Notification) {
        hide()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 125: move(by: 1)
        case 126: move(by: -1)
        case 48: move(by: modifiers.contains(.shift) ? -1 : 1)
        case 36, 76: choose(model.selection)
        case 53: hide()
        default:
            guard modifiers == .command, let index = Self.digitKeyCodes.firstIndex(of: event.keyCode) else { return event }
            choose(index)
        }
        return nil
    }

    private func move(by offset: Int) {
        let count = model.results.count
        guard count > 0 else { return }
        model.selection = (model.selection + offset + count) % count
        announceSelection()
    }

    private func choose(_ index: Int) {
        let results = model.results
        guard results.indices.contains(index) else { return }
        hide()
        Switcher.shared.select(results[index], showsIndicator: false)
    }

    private func announceSelection() {
        let results = model.results
        guard results.indices.contains(model.selection) else { return }
        Feedback.announce(results[model.selection].name, from: panel)
    }

    private func layout(recenter: Bool = false) {
        let rows = min(max(model.results.count, 1), Self.maximumRows)
        let height = Self.headerHeight + CGFloat(rows) * Self.rowHeight + 16
        var frame = panel.frame
        if recenter || !panel.isVisible {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            frame = NSRect(
                x: visible.midX - Self.width / 2, y: visible.maxY - visible.height * 0.22 - height, width: Self.width, height: height)
        } else {
            frame.origin.y += frame.height - height
            frame.size.height = height
        }
        panel.setFrame(frame.integral, display: true)
        if model.selection >= model.results.count { model.selection = 0 }
    }
}

private struct QuickSwitcherView: View {
    @Bindable var model: SwitcherModel
    let rowHeight: CGFloat
    let headerHeight: CGFloat
    let choose: (Int) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let results = model.results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(L.switcherPrompt, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($focused)
                    .accessibilityLabel(L.switcherSearchAccessibility)
                    .onChange(of: model.query) { model.selection = 0 }
            }
            .padding(.horizontal, 18)
            .frame(height: headerHeight)
            Divider().padding(.horizontal, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if results.isEmpty {
                            Text(L.switcherNoResults)
                                .foregroundStyle(.secondary)
                                .frame(height: rowHeight)
                        }
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, source in
                            SwitcherRow(source: source, index: index, isSelected: index == model.selection, height: rowHeight) {
                                choose(index)
                            }
                            .id(source.id)
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selection) {
                    guard results.indices.contains(model.selection) else { return }
                    proxy.scrollTo(results[model.selection].id)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .onAppear { focused = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in focused = true }
    }
}

private struct SwitcherRow: View {
    @Environment(Preferences.self) private var prefs
    let source: InputSource
    let index: Int
    let isSelected: Bool
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SourceIcon(source: source, size: 24)
                Text(source.name)
                    .font(.body.weight(source == Switcher.shared.current ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let shortcut = KeyboardShortcuts.getShortcut(for: .source(source.id)) {
                    Text(shortcut.description)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
                Text(prefs.label(for: source))
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(minWidth: 34)
                if index < 9 {
                    Text(verbatim: "⌘\(index + 1)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color(nsColor: .tertiaryLabelColor))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14).fill(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
