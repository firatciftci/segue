import Foundation
import Observation

@Observable
final class CommandLineTool {
    static let shared = CommandLineTool()

    private(set) var installedURL: URL?
    private(set) var isStale = false

    @ObservationIgnored private let files = FileManager.default

    private init() {}

    static let name = "segue"

    var bundledURL: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/\(Self.name)")
    }

    private var directories: Array<URL> {
        [
            URL(filePath: "/opt/homebrew/bin"), URL(filePath: "/usr/local/bin"),
            files.homeDirectoryForCurrentUser.appending(path: ".local/bin"),
        ]
    }

    func refresh() {
        installedURL = nil
        isStale = false
        for directory in directories {
            let link = directory.appending(path: Self.name)
            guard let destination = try? files.destinationOfSymbolicLink(atPath: link.path) else { continue }
            installedURL = link
            isStale = URL(filePath: destination).standardizedFileURL != bundledURL.standardizedFileURL
            return
        }
    }

    func install() throws {
        if let installedURL { try files.removeItem(at: installedURL) }
        let directory =
            directories.first { files.isWritableFile(atPath: $0.path) }
            ?? directories[directories.count - 1]
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        try files.createSymbolicLink(at: directory.appending(path: Self.name), withDestinationURL: bundledURL)
        refresh()
    }

    func uninstall() throws {
        if let installedURL { try files.removeItem(at: installedURL) }
        refresh()
    }
}

enum URLRouter {
    static func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "segue", let action = url.host()?.lowercased() else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let argument =
            url.pathComponents.dropFirst().first
            ?? components?.queryItems?.first { ["source", "group", "tab"].contains($0.name) }?.value
        let switcher = Switcher.shared
        switch action {
        case "select":
            guard let argument,
                let source = InputSource.matching(argument, in: switcher.sources, labels: Preferences.shared.labels)
            else { return }
            switcher.select(source)
        case "cycle":
            guard let argument, let group = Preferences.shared.group(matching: argument) else { return }
            switcher.cycle(group.id)
        case "switcher":
            QuickSwitcher.shared.show()
        case "settings":
            SettingsWindowController.shared.show(argument.flatMap(SettingsTab.init(name:)))
        default:
            break
        }
    }
}
