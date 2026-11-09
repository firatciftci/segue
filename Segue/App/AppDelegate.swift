import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_: Notification) {
        if let appearance = DemoData.appearance { NSApp.appearance = NSAppearance(named: appearance) }
        NSApp.mainMenu = Self.makeMainMenu()
        Switcher.shared.start()
        if !DemoData.isEnabled { AutoSwitcher.shared.start() }
        ModifierTaps.shared.start()
        ShortcutAudit.shared.start()
        _ = Updater.shared
        menuBar = MenuBarController()
        let defaults = Preferences.store
        if !defaults.bool(forKey: "hasLaunched") {
            defaults.set(true, forKey: "hasLaunched")
            SettingsWindowController.shared.show(.sources)
        }
    }

    func application(_: NSApplication, open urls: Array<URL>) {
        for url in urls { URLRouter.handle(url) }
    }

    func applicationDidBecomeActive(_: Notification) {
        ModifierTaps.shared.refreshAuthorization()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L.settingsMenu, action: #selector(Self.openSettings), keyEquivalent: ",")
        if Updater.shared.isAvailable {
            appMenu.addItem(withTitle: L.checkForUpdatesMenu, action: #selector(Updater.checkForUpdates(_:)), keyEquivalent: "").target =
                Updater.shared
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window
        return main
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show()
    }
}

func trackChanges(_ body: @escaping @MainActor @Sendable () -> Void) {
    withObservationTracking {
        body()
    } onChange: {
        Task { @MainActor in trackChanges(body) }
    }
}
