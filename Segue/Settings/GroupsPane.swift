import SwiftUI

struct GroupsPane: View {
    @Environment(Preferences.self) private var prefs
    @Environment(Switcher.self) private var switcher

    var body: some View {
        @Bindable var prefs = prefs
        if prefs.groups.isEmpty {
            ContentUnavailableView {
                Label(L.groupsEmptyTitle, systemImage: "square.stack")
            } description: {
                Text(L.groupsEmptyDescription)
            } actions: {
                Button(L.addGroup, action: addGroup)
            }
            .padding(.vertical, 48)
        } else {
            VStack(spacing: 0) {
                Form {
                    ForEach($prefs.groups) { $group in
                        GroupSection(group: $group)
                    }
                }
                .formStyle(.grouped)
                HStack {
                    Spacer()
                    Button(L.addGroup, systemImage: "plus", action: addGroup)
                }
                .padding([.horizontal, .bottom], 20)
            }
        }
    }

    private func addGroup() {
        withAnimation { _ = switcher.addGroup() }
    }
}

private struct GroupSection: View {
    @Environment(Switcher.self) private var switcher
    @Binding var group: SourceGroup
    @State private var confirmingRemoval = false
    @State private var removingMember: InputSource?

    private var members: Array<InputSource> {
        group.sourceIDs.compactMap(switcher.source)
    }

    private var candidates: Array<InputSource> {
        switcher.sources.filter { !group.sourceIDs.contains($0.id) }
    }

    var body: some View {
        Section {
            TextField(L.groupName, text: $group.name)
            LabeledContent(L.groupShortcut) {
                ShortcutRecorder(name: .group(group.id), accessibilityLabel: L.shortcutAccessibility(group.name))
            }
            ForEach(members) { source in
                HStack(spacing: 8) {
                    Label {
                        Text(source.name)
                    } icon: {
                        SourceIcon(source: source, size: 18)
                    }
                    Spacer()
                    Button(L.groupRemoveSource(source.name), systemImage: "minus.circle.fill") { removingMember = source }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(L.groupRemoveSource(source.name))
                }
            }
            .reorderable()
            Menu(L.groupAddSource) {
                ForEach(candidates) { source in
                    Button {
                        withAnimation { group.sourceIDs.append(source.id) }
                    } label: {
                        Label {
                            Text(source.name)
                        } icon: {
                            Image(nsImage: source.icon.menuSized)
                        }
                    }
                }
            }
            .disabled(candidates.isEmpty)
        } header: {
            Text(group.name)
        } footer: {
            HStack(alignment: .firstTextBaseline) {
                Text(members.count < 2 ? L.groupNeedsTwo : L.groupFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L.removeGroup, role: .destructive) { confirmingRemoval = true }
            }
        }
        .confirmsRemoval(L.removeTitle(group.name), message: L.removeGroupMessage, action: L.removeGroup, isPresented: $confirmingRemoval) {
            let id = group.id
            withAnimation { switcher.removeGroup(id) }
        }
        .confirmsRemoval(
            L.removeMemberTitle(removingMember?.name ?? "", group.name), message: L.removeMemberMessage, action: L.removeConfirm,
            isPresented: Binding {
                removingMember != nil
            } set: {
                if !$0 { removingMember = nil }
            }
        ) {
            guard let id = removingMember?.id else { return }
            withAnimation { group.sourceIDs.removeAll { $0 == id } }
        }
        .reorderContainer(for: InputSource.self) { difference in
            move(difference.sources, to: difference.destination.position)
        }
    }

    private func move(
        _ moving: Array<String>, to position: ReorderDifference<String, ReorderableSingleCollectionIdentifier>.Destination.Position
    ) {
        var ids = group.sourceIDs.filter { !moving.contains($0) }
        let ordered = group.sourceIDs.filter { moving.contains($0) }
        switch position {
        case .before(let target):
            ids.insert(contentsOf: ordered, at: ids.firstIndex(of: target) ?? ids.endIndex)
        case .end:
            ids.append(contentsOf: ordered)
        }
        withAnimation { group.sourceIDs = ids }
    }
}
