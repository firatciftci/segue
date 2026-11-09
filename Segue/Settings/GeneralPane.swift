import ServiceManagement
import SwiftUI

struct GeneralPane: View {
    @Environment(Preferences.self) private var prefs
    @Environment(Switcher.self) private var switcher
    @Environment(CommandLineTool.self) private var commandLine
    @Environment(Updater.self) private var updater
    @State private var commandLineError: String?
    @State private var confirmingUninstall = false
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var kawaCount = 0
    @State private var importedCount: Int?
    @State private var backupMessage: String?
    @State private var exportedURL: URL?

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Section {
                Toggle(isOn: launchAtLogin) {
                    Text(L.launchAtLogin)
                    if loginStatus == .requiresApproval {
                        Text(L.launchAtLoginApproval)
                    }
                }
            }
            Section {
                Toggle(L.showInMenuBar, isOn: $prefs.showInMenuBar)
                Picker(L.menuBarStyle, selection: $prefs.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!prefs.showInMenuBar)
                Toggle(isOn: $prefs.showInDock) {
                    Text(L.showInDock)
                    Text(L.showInDockDetail)
                }
                .onChange(of: prefs.showInDock) { SettingsWindowController.shared.updateDockIcon() }
            } footer: {
                Text(L.hiddenFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Picker(L.indicatorMode, selection: $prefs.indicatorMode) {
                    ForEach(IndicatorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker(L.indicatorPosition, selection: $prefs.indicatorPosition) {
                    ForEach(IndicatorPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .disabled(prefs.indicatorMode == .never)
            } header: {
                Text(L.indicatorSection)
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text(L.indicatorFooter)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(L.indicatorPreview, action: preview)
                        .disabled(switcher.current == nil)
                }
            }
            if updater.isAvailable {
                Section {
                    @Bindable var updater = updater
                    LabeledContent {
                        Button(L.checkForUpdates) { updater.checkForUpdates(nil) }
                    } label: {
                        Text(L.updatesTitle)
                        Text(L.updatesVersion(Self.version))
                    }
                    Toggle(L.automaticUpdates, isOn: $updater.automaticallyChecks)
                }
            }
            Section {
                LabeledContent {
                    HStack {
                        if commandLine.installedURL != nil {
                            Button(L.cliUninstall) { confirmingUninstall = true }
                        }
                        if commandLine.installedURL == nil || commandLine.isStale {
                            Button(commandLine.isStale ? L.cliReinstall : L.cliInstall, action: installCommandLine)
                        }
                    }
                } label: {
                    Text(L.cliTitle)
                    if let commandLineError {
                        Text(commandLineError)
                    } else if let url = commandLine.installedURL {
                        Text(commandLine.isStale ? L.cliStale(url.path) : L.cliInstalled(url.path))
                    } else {
                        Text(L.cliDetail)
                    }
                }
                .confirmsRemoval(
                    L.cliUninstallTitle, message: L.cliUninstallMessage, action: L.cliUninstall, isPresented: $confirmingUninstall,
                    perform: uninstallCommandLine)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.cliFooter)
                    Text(verbatim: "segue select ABC  ·  segue list  ·  open segue://switcher")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                LabeledContent {
                    HStack {
                        Button(L.importSettings) { Task { await importSettings() } }
                        Button(L.exportSettings) { Task { await exportSettings() } }
                    }
                } label: {
                    Text(L.backupTitle)
                    Text(L.backupDetail)
                }
                if let backupMessage {
                    LabeledContent {
                        if let exportedURL {
                            Button(L.showInFinder) { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]) }
                        }
                    } label: {
                        Label(backupMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            if kawaCount > 0 || importedCount != nil {
                Section {
                    LabeledContent {
                        if let importedCount {
                            Label(importedCount == 0 ? L.kawaNothing : L.kawaImported(importedCount), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        } else {
                            Button(L.kawaImport, action: importFromKawa)
                                .transition(.opacity)
                        }
                    } label: {
                        Text(L.kawaTitle)
                        Text(L.kawaDetail)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginStatus = SMAppService.mainApp.status
            kawaCount = KawaImporter.shortcuts().count
            commandLine.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding {
            loginStatus == .enabled || loginStatus == .requiresApproval
        } set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                let window = NSApp.keyWindow
                Task { await Feedback.alert(L.loginFailedTitle, error.localizedDescription, in: window) }
            }
            loginStatus = SMAppService.mainApp.status
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func installCommandLine() {
        do {
            try commandLine.install()
            commandLineError = nil
        } catch {
            commandLineError = L.cliFailed(error.localizedDescription)
        }
    }

    private func uninstallCommandLine() {
        do {
            try commandLine.uninstall()
            commandLineError = nil
        } catch {
            commandLineError = L.cliFailed(error.localizedDescription)
        }
    }

    private func preview() {
        guard let current = switcher.current else { return }
        Indicator.shared.show(current, detail: nil)
    }

    private func importFromKawa() {
        let count = KawaImporter.importShortcuts()
        withAnimation(.easeOut(duration: 0.15)) { importedCount = count }
        Feedback.announce(count == 0 ? L.kawaNothing : L.kawaImported(count))
    }

    private func exportSettings() async {
        guard let url = await SettingsArchive.export() else { return }
        report(L.exportedStatus(FileManager.default.displayName(atPath: url.path)), exported: url)
    }

    private func importSettings() async {
        guard let url = await SettingsArchive.importFile() else { return }
        report(L.importedStatus(FileManager.default.displayName(atPath: url.path)), exported: nil)
    }

    private func report(_ message: String, exported url: URL?) {
        withAnimation(.easeOut(duration: 0.15)) {
            backupMessage = message
            exportedURL = url
        }
        Feedback.announce(message)
    }
}
