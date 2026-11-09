import SwiftUI
import UniformTypeIdentifiers

struct AppsPane: View {
    @Environment(Preferences.self) private var prefs
    @Environment(Switcher.self) private var switcher
    @Environment(AutoSwitcher.self) private var autoSwitcher
    @State private var isPickingApps = false

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Section {
                Toggle(isOn: $prefs.rememberAppSources) {
                    Text(L.rememberApps)
                    Text(L.rememberAppsDetail)
                }
                .onChange(of: prefs.rememberAppSources) { _, enabled in
                    if !enabled { prefs.appMemory = [:] }
                }
            }
            Section {
                if prefs.appRules.isEmpty {
                    Text(L.appRulesEmpty)
                        .foregroundStyle(.secondary)
                }
                ForEach($prefs.appRules) { $rule in
                    AppRuleRow(rule: $rule) {
                        let id = rule.id
                        withAnimation { prefs.appRules.removeAll { $0.id == id } }
                    }
                }
                HStack {
                    Spacer()
                    Button(L.addApp, systemImage: "plus") { isPickingApps = true }
                        .disabled(switcher.sources.isEmpty)
                }
            } header: {
                Text(L.appRulesSection)
            } footer: {
                Text(L.appRulesFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                if prefs.websiteRules.isEmpty {
                    Text(L.websiteRulesEmpty)
                        .foregroundStyle(.secondary)
                }
                ForEach($prefs.websiteRules) { $rule in
                    WebsiteRuleRow(rule: $rule) {
                        let id = rule.id
                        withAnimation { prefs.websiteRules.removeAll { $0.id == id } }
                    }
                }
                ForEach(autoSwitcher.deniedBrowsers.sorted(), id: \.self) { bundleID in
                    LabeledContent {
                        Button(L.automationAllow) { PrivacySettings.open(.automation) }
                    } label: {
                        Label {
                            Text(L.automationTitle(Browser.name(of: bundleID)))
                            Text(L.automationDetail)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.multicolor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button(L.addWebsite, systemImage: "plus", action: addWebsite)
                        .disabled(switcher.sources.isEmpty)
                }
            } header: {
                Text(L.websitesSection)
            } footer: {
                Text(L.websitesFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isPickingApps) {
            AppPicker(excluded: Set(prefs.appRules.map(\.bundleID))) { bundleIDs in
                for bundleID in bundleIDs { add(bundleID) }
            }
        }
    }

    private var defaultSourceID: String? {
        (switcher.current ?? switcher.sources.first)?.id
    }

    private func add(_ bundleID: String) {
        guard let sourceID = defaultSourceID, !prefs.appRules.contains(where: { $0.bundleID == bundleID }) else { return }
        withAnimation { prefs.appRules.append(AppRule(bundleID: bundleID, sourceID: sourceID)) }
    }

    private func addWebsite() {
        guard let sourceID = defaultSourceID else { return }
        withAnimation { prefs.websiteRules.append(WebsiteRule(domain: "", sourceID: sourceID)) }
    }
}

struct AppInfo {
    let bundleID: String
    let name: String
    let icon: NSImage

    init(_ bundleID: String) {
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            name = bundleID
            icon = NSWorkspace.shared.icon(for: .application)
        }
    }
}

private struct SourcePicker: View {
    @Environment(Switcher.self) private var switcher
    let title: String
    @Binding var sourceID: String

    var body: some View {
        Picker(title, selection: $sourceID) {
            ForEach(switcher.sources) { source in
                Label {
                    Text(source.name)
                } icon: {
                    Image(nsImage: source.icon.menuSized)
                }
                .tag(source.id)
            }
            if switcher.source(sourceID) == nil {
                Text(L.sourceUnavailable).tag(sourceID)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

private struct AppRuleRow: View {
    @Binding var rule: AppRule
    let remove: () -> Void
    @State private var confirming = false

    var body: some View {
        let app = AppInfo(rule.bundleID)
        HStack(spacing: 8) {
            Label {
                Text(app.name)
                    .lineLimit(1)
            } icon: {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 8)
            SourcePicker(title: L.ruleSourceAccessibility(app.name), sourceID: $rule.sourceID)
            Button(L.removeRule(app.name), systemImage: "minus.circle.fill") { confirming = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(L.removeRule(app.name))
        }
        .confirmsRemoval(
            L.removeRuleTitle(app.name), message: L.removeAppRuleMessage, action: L.removeRuleConfirm, isPresented: $confirming,
            perform: remove)
    }
}

private struct WebsiteRuleRow: View {
    @Binding var rule: WebsiteRule
    let remove: () -> Void
    @FocusState private var focused: Bool
    @State private var confirming = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(L.websiteDomain, text: $rule.domain, prompt: Text(verbatim: "example.com"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($focused)
                .onSubmit(normalize)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { normalize() }
                }
                .onAppear {
                    if rule.domain.isEmpty { focused = true }
                }
                .accessibilityLabel(L.websiteDomain)
            Spacer(minLength: 8)
            SourcePicker(title: L.ruleSourceAccessibility(rule.normalizedDomain), sourceID: $rule.sourceID)
            Button(L.removeRule(rule.normalizedDomain), systemImage: "minus.circle.fill") {
                if rule.normalizedDomain.isEmpty { remove() } else { confirming = true }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(L.removeRule(rule.normalizedDomain))
        }
        .confirmsRemoval(
            L.removeRuleTitle(rule.normalizedDomain), message: L.removeWebsiteRuleMessage, action: L.removeRuleConfirm,
            isPresented: $confirming, perform: remove)
    }

    private func normalize() {
        let normalized = rule.normalizedDomain
        if normalized != rule.domain { rule.domain = normalized }
    }
}
