import AppKit
import SwiftUI

struct ShortcutsPane: View {
    @Environment(Preferences.self) private var prefs
    @Environment(Switcher.self) private var switcher
    @Environment(ModifierTaps.self) private var taps
    @Environment(ShortcutAudit.self) private var audit

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Section {
                LabeledContent {
                    ShortcutRecorder(name: .quickSwitcher, accessibilityLabel: L.quickSwitcherTitle)
                } label: {
                    Text(L.quickSwitcherTitle)
                    Text(L.quickSwitcherDetail)
                }
            }
            Section {
                if !prefs.modifierTriggers.isEmpty, !taps.isAuthorized {
                    LabeledContent {
                        Button(L.inputMonitoringAllow, action: taps.requestAccess)
                    } label: {
                        Label {
                            Text(L.inputMonitoringTitle)
                            Text(L.inputMonitoringDetail)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.multicolor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                ForEach($prefs.modifierTriggers) { $trigger in
                    TriggerRow(trigger: $trigger) {
                        let id = trigger.id
                        withAnimation { prefs.modifierTriggers.removeAll { $0.id == id } }
                    }
                }
                HStack {
                    Spacer()
                    Button(L.addModifierKey, systemImage: "plus", action: addTrigger)
                        .disabled(switcher.sources.isEmpty)
                }
            } header: {
                Text(L.modifierSection)
            } footer: {
                Text(L.modifierFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let conflicts = ShortcutAudit.names().compactMap { entry in audit.conflict(for: entry.name).map { (entry.title, $0) } }
            if !conflicts.isEmpty {
                Section {
                    ForEach(conflicts, id: \.0) { title, message in
                        LabeledContent {
                            Text(message)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Label {
                                Text(title)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                } header: {
                    Text(L.conflictsSection)
                } footer: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L.conflictsFooter)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(L.openKeyboardSettings, action: KeyboardSettings.open)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            taps.refreshAuthorization()
            audit.refresh()
        }
    }

    private func addTrigger() {
        let used = Set(prefs.modifierTriggers.map { "\($0.key.rawValue).\($0.gesture.rawValue)" })
        let key = ModifierKey.allCases.first { !used.contains("\($0.rawValue).\(TapGesture.tap.rawValue)") } ?? .rightCommand
        let target = switcher.sources.first { $0 != switcher.current }.map { TriggerTarget.source($0.id) } ?? .quickSwitcher
        withAnimation {
            prefs.modifierTriggers.append(ModifierTrigger(key: key, gesture: .tap, target: target))
        }
        if !taps.isAuthorized { taps.requestAccess() }
    }
}

private struct TriggerRow: View {
    @Environment(Preferences.self) private var prefs
    @Environment(Switcher.self) private var switcher
    @Binding var trigger: ModifierTrigger
    let remove: () -> Void
    @State private var confirming = false

    private static let keyWidth = NSPopUpButton.fittingWidth(ModifierKey.allCases.map(\.title))
    private static let gestureWidth = NSPopUpButton.fittingWidth(TapGesture.allCases.map(\.title))

    var body: some View {
        HStack(spacing: 8) {
            PopUpPicker(title: L.modifierKeyLabel, sections: [ModifierKey.allCases.map { ($0.title, $0) }], selection: $trigger.key)
                .frame(width: Self.keyWidth)
            PopUpPicker(title: L.modifierGestureLabel, sections: [TapGesture.allCases.map { ($0.title, $0) }], selection: $trigger.gesture)
                .frame(width: Self.gestureWidth)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            PopUpPicker(title: L.modifierTargetLabel, sections: targets, selection: $trigger.target)
                .frame(maxWidth: .infinity)
            Button(L.removeModifierKey, systemImage: "minus.circle.fill") { confirming = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(L.removeModifierKey)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .confirmsRemoval(
            L.removeTitle(title), message: L.removeModifierMessage, action: L.removeModifierKey, isPresented: $confirming, perform: remove)
    }

    private var targets: Array<Array<(String, TriggerTarget)>> {
        [
            switcher.sources.map { ($0.name, .source($0.id)) },
            prefs.groups.map { ($0.name, .group($0.id)) },
            [(L.quickSwitcherTitle, .quickSwitcher)],
        ]
    }

    private var title: String {
        L.modifierRowAccessibility(trigger.key.title, trigger.gesture.title)
    }
}

private struct PopUpPicker<Value: Hashable>: NSViewRepresentable {
    let title: String
    let sections: Array<Array<(String, Value)>>
    @Binding var selection: Value

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel(title)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let menu = NSMenu()
        var values: Array<Value> = []
        for section in sections where !section.isEmpty {
            if !values.isEmpty { menu.addItem(.separator()) }
            for (name, value) in section {
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                item.tag = values.count
                values.append(value)
                menu.addItem(item)
            }
        }
        if !values.contains(selection) {
            let item = NSMenuItem(title: L.sourceUnavailable, action: nil, keyEquivalent: "")
            item.tag = -1
            item.isEnabled = false
            menu.insertItem(item, at: 0)
        }
        button.menu = menu
        button.selectItem(withTag: values.firstIndex(of: selection) ?? -1)
        context.coordinator.choose = { index in
            guard values.indices.contains(index) else { return }
            selection = values[index]
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: NSPopUpButton, context _: Context) -> CGSize? {
        CGSize(width: proposal.width ?? button.intrinsicContentSize.width, height: button.intrinsicContentSize.height)
    }

    final class Coordinator: NSObject {
        var choose: (Int) -> Void = { _ in }

        @objc func choose(_ sender: NSPopUpButton) {
            choose(sender.selectedTag())
        }
    }
}

extension NSPopUpButton {
    static func fittingWidth(_ titles: Array<String>) -> CGFloat {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItems(withTitles: titles)
        var widest: CGFloat = 0
        for index in titles.indices {
            button.selectItem(at: index)
            widest = max(widest, button.intrinsicContentSize.width)
        }
        return ceil(widest)
    }
}
