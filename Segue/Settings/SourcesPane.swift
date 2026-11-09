import KeyboardShortcuts
import SwiftUI

struct SourcesPane: View {
    @Environment(Switcher.self) private var switcher

    var body: some View {
        Form {
            Section {
                if switcher.sources.isEmpty {
                    Text(L.noSources)
                        .foregroundStyle(.secondary)
                }
                ForEach(switcher.sources) { source in
                    SourceRow(source: source, isCurrent: source == switcher.current)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.sourcesFooter)
                    HStack(alignment: .firstTextBaseline) {
                        Text(L.sourcesManage)
                        Spacer()
                        Button(L.openKeyboardSettings, action: KeyboardSettings.open)
                    }
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SourceRow: View {
    @Environment(Preferences.self) private var prefs
    let source: InputSource
    let isCurrent: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(L.labelPlaceholder, text: label, prompt: Text(source.defaultLabel))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .accessibilityLabel(L.labelAccessibility(source.name))
                ShortcutRecorder(name: .source(source.id), accessibilityLabel: L.shortcutAccessibility(source.name))
            }
        } label: {
            Label {
                Text(source.name)
                    .fontWeight(isCurrent ? .semibold : .regular)
            } icon: {
                SourceIcon(source: source, size: 20)
            }
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var label: Binding<String> {
        Binding {
            prefs.labels[source.id] ?? ""
        } set: { value in
            let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4))
            prefs.labels[source.id] = trimmed.isEmpty ? nil : trimmed
        }
    }
}

struct SourceIcon: View {
    let source: InputSource
    let size: CGFloat

    var body: some View {
        Image(nsImage: source.icon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.22))
            .accessibilityHidden(true)
    }
}

struct ShortcutRecorder: View {
    @Environment(ShortcutAudit.self) private var audit
    let name: KeyboardShortcuts.Name
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 6) {
            if let conflict = audit.conflict(for: name) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .help(conflict)
                    .accessibilityLabel(conflict)
            }
            KeyboardShortcuts.Recorder(for: name)
                .shortcutValidation { shortcut in audit.validate(shortcut, for: name) }
                .accessibilityLabel(accessibilityLabel)
        }
    }
}
