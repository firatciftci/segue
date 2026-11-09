import AppKit
import Observation

@Observable
final class AutoSwitcher {
    static let shared = AutoSwitcher()

    private(set) var deniedBrowsers: Set<String> = []

    @ObservationIgnored private let prefs = Preferences.shared
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var app: NSRunningApplication?
    @ObservationIgnored private var context: String?

    private init() {}

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.activated(app) }
        }
        activated(NSWorkspace.shared.frontmostApplication)
    }

    func sourceDidChange(_ source: InputSource) {
        guard prefs.rememberAppSources, let context, context.hasPrefix(Self.appPrefix) else { return }
        let bundleID = String(context.dropFirst(Self.appPrefix.count))
        guard !prefs.appRules.contains(where: { $0.bundleID == bundleID }), prefs.appMemory[bundleID] != source.id else { return }
        prefs.appMemory[bundleID] = source.id
    }

    func rulesDidChange() {
        context = nil
        activated(NSWorkspace.shared.frontmostApplication)
    }

    private static let appPrefix = "app:"

    private func activated(_ app: NSRunningApplication?) {
        timer?.invalidate()
        timer = nil
        guard let app, let bundleID = app.bundleIdentifier, bundleID != Bundle.main.bundleIdentifier else {
            self.app = nil
            context = nil
            return
        }
        self.app = app
        if Browser.supports(bundleID), !prefs.websiteRules.isEmpty {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
            timer?.tolerance = 0.3
        }
        evaluate()
    }

    private func evaluate() {
        guard let app, let bundleID = app.bundleIdentifier else { return }
        if Browser.supports(bundleID), !prefs.websiteRules.isEmpty, let host = host(in: bundleID),
            let rule = prefs.websiteRules.first(where: { $0.matches(host) })
        {
            apply("web:\(bundleID):\(rule.id.uuidString)", sourceID: rule.sourceID, detail: rule.normalizedDomain)
            return
        }
        let key = Self.appPrefix + bundleID
        let name = app.localizedName ?? bundleID
        if let rule = prefs.appRules.first(where: { $0.bundleID == bundleID }) {
            apply(key, sourceID: rule.sourceID, detail: name)
        } else if prefs.rememberAppSources, let remembered = prefs.appMemory[bundleID] {
            apply(key, sourceID: remembered, detail: name)
        } else {
            context = key
        }
    }

    private func apply(_ key: String, sourceID: String, detail: String) {
        guard key != context else { return }
        context = key
        let switcher = Switcher.shared
        guard let source = switcher.source(sourceID), source != switcher.current else { return }
        switcher.select(source, detail: detail)
    }

    private func host(in bundleID: String) -> String? {
        switch Browser.currentURL(in: bundleID) {
        case .success(let url):
            if deniedBrowsers.contains(bundleID) { deniedBrowsers.remove(bundleID) }
            return url?.host()
        case .failure(.denied):
            if !deniedBrowsers.contains(bundleID) { deniedBrowsers.insert(bundleID) }
            return nil
        case .failure(.unavailable):
            return nil
        }
    }
}

enum Browser {
    enum Failure: Error {
        case denied
        case unavailable
    }

    private static let safari: Array<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]
    private static let chromium: Array<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary", "company.thebrowser.Browser",
        "com.brave.Browser", "com.microsoft.edgemac", "net.imput.helium", "com.vivaldi.Vivaldi", "org.chromium.Chromium",
    ]
    private static var scripts: Dictionary<String, NSAppleScript> = [:]

    static func supports(_ bundleID: String) -> Bool {
        safari.contains(bundleID) || chromium.contains(bundleID)
    }

    static func name(of bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { FileManager.default.displayName(atPath: $0.path) }?
            .replacingOccurrences(of: ".app", with: "") ?? bundleID
    }

    static func currentURL(in bundleID: String) -> Result<URL?, Failure> {
        guard let script = script(for: bundleID), let target = NSAppleEventDescriptor(bundleIdentifier: bundleID).aeDesc else {
            return .failure(.unavailable)
        }
        if AEDeterminePermissionToAutomateTarget(target, typeWildCard, typeWildCard, false) == OSStatus(errAEEventNotPermitted) {
            return .failure(.denied)
        }
        let result = script.executeAndReturnError(nil)
        return .success(result.stringValue.flatMap { $0.isEmpty ? nil : URL(string: $0) })
    }

    private static func script(for bundleID: String) -> NSAppleScript? {
        if let cached = scripts[bundleID] { return cached }
        let tab = safari.contains(bundleID) ? "current tab" : "active tab"
        let source = """
            with timeout of 1 second
                tell application id "\(bundleID)"
                    if (count of windows) is 0 then return ""
                    return URL of \(tab) of front window
                end tell
            end timeout
            """
        guard let script = NSAppleScript(source: source) else { return nil }
        scripts[bundleID] = script
        return script
    }
}
