import SwiftUI
import UniformTypeIdentifiers

struct AppPicker: View {
    let excluded: Set<String>
    let add: (Array<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var apps: Array<InstalledApp>?
    @State private var query = ""
    @State private var selection: Set<String> = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.addAppsTitle)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                searchField
            }
            .padding(16)
            Divider()
            content
            Divider()
            HStack {
                Button(L.chooseApp, action: chooseApp)
                Spacer()
                Button(L.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L.addSelected) { commit((apps ?? []).map(\.bundleID).filter(selection.contains)) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420, height: 540)
        .task {
            let running = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleURL)
            apps = await InstalledApp.load(excluding: excluded, including: running)
        }
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(L.searchApps, text: $query, prompt: Text(L.searchApps))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($isSearchFocused)
            if !query.isEmpty {
                Button(L.clearSearch, systemImage: "xmark.circle.fill") { query = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.fill.tertiary, in: .capsule)
    }

    @ViewBuilder private var content: some View {
        if let apps {
            let matches = filtered(apps)
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(matches, id: \.bundleID) { app in
                    AppPickerRow(app: app, isSelected: selection.contains(app.bundleID)) { toggle(app.bundleID) }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func filtered(_ apps: Array<InstalledApp>) -> Array<InstalledApp> {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedStandardContains(query) || $0.bundleID.localizedStandardContains(query) }
    }

    private func toggle(_ bundleID: String) {
        if selection.contains(bundleID) {
            selection.remove(bundleID)
        } else {
            selection.insert(bundleID)
        }
    }

    private func commit(_ bundleIDs: Array<String>) {
        add(bundleIDs)
        dismiss()
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowsMultipleSelection = true
        Task {
            let response: NSApplication.ModalResponse =
                if let window = NSApp.keyWindow { await panel.beginSheetModal(for: window) } else { panel.runModal() }
            guard response == .OK else { return }
            commit(panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
        }
    }
}

private struct AppPickerRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(app.name)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct InstalledApp: Sendable {
    let bundleID: String
    let name: String
    let url: URL

    @concurrent
    nonisolated static func load(excluding excluded: Set<String>, including running: Array<URL>) async -> Array<Self> {
        let fileManager = FileManager.default
        let roots = [
            URL(filePath: "/Applications"), URL(filePath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appending(path: "Applications"),
        ]
        var urls = running
        for root in roots { urls += applications(in: root) }
        var seen = excluded
        if let own = Bundle.main.bundleIdentifier { seen.insert(own) }
        var apps: Array<Self> = []
        for url in urls {
            guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier, !seen.contains(bundleID) else { continue }
            let info = bundle.infoDictionary ?? [:]
            guard !isSet(info["LSUIElement"]), !isSet(info["LSBackgroundOnly"]) else { continue }
            seen.insert(bundleID)
            let name = fileManager.displayName(atPath: url.path)
            apps.append(Self(bundleID: bundleID, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name, url: url))
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private nonisolated static func applications(in root: URL) -> Array<URL> {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }
        var urls: Array<URL> = []
        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                urls.append(url)
            } else if enumerator.level >= 3 {
                enumerator.skipDescendants()
            }
        }
        return urls
    }

    private nonisolated static func isSet(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool: flag
        case let text as String: ["1", "yes", "true"].contains(text.lowercased())
        default: false
        }
    }
}
