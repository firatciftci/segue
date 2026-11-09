import Foundation

enum L {
    static let settingsMenu = String(localized: "Settings…")
    static let quit = String(localized: "Quit Segue")
    static let openKeyboardSettings = String(localized: "Open Keyboard Settings…")
    static let noSources = String(localized: "No Input Sources")
    static func menuBarAccessibility(_ name: String) -> String { String(localized: "Segue, \(name)") }
    static let quickSwitcherMenu = String(localized: "Quick Switcher…")
    static let checkForUpdatesMenu = String(localized: "Check for Updates…")

    static let tabGeneral = String(localized: "General")
    static let tabSources = String(localized: "Input Sources")
    static let tabGroups = String(localized: "Groups")
    static let tabShortcuts = String(localized: "Shortcuts")
    static let tabApps = String(localized: "Apps")

    static let launchAtLogin = String(localized: "Open at Login")
    static let launchAtLoginApproval = String(localized: "Allow Segue in System Settings > General > Login Items & Extensions.")
    static let showInMenuBar = String(localized: "Show in Menu Bar")
    static let showInDock = String(localized: "Show in Dock")
    static let showInDockDetail = String(localized: "Segue appears in the Dock and the app switcher while Settings is open.")
    static let menuBarStyle = String(localized: "Menu Bar Shows")
    static let menuBarStyleLabel = String(localized: "Label")
    static let menuBarStyleIcon = String(localized: "Icon")
    static let hiddenFooter = String(
        localized: "If Segue is hidden from the menu bar, open it again from Finder or Spotlight to get back to these settings.")

    static let indicatorSection = String(localized: "Indicator")
    static let indicatorMode = String(localized: "Show Indicator")
    static let indicatorNever = String(localized: "Never")
    static let indicatorSegue = String(localized: "When Segue Switches")
    static let indicatorAlways = String(localized: "On Every Change")
    static let indicatorPosition = String(localized: "Position")
    static let positionTopRight = String(localized: "Top Right")
    static let positionCenter = String(localized: "Center")
    static let positionBottom = String(localized: "Bottom")
    static let indicatorPreview = String(localized: "Preview")
    static let indicatorFooter = String(localized: "The indicator briefly shows the input source you switched to.")

    static let automaticUpdates = String(localized: "Check for Updates Automatically")
    static let checkForUpdates = String(localized: "Check Now")
    static let updatesTitle = String(localized: "Updates")
    static func updatesVersion(_ version: String) -> String { String(localized: "Version \(version)") }

    static let cliTitle = String(localized: "Command-Line Tool")
    static let cliDetail = String(localized: "Switch input sources from Terminal and scripts with the segue command.")
    static let cliInstall = String(localized: "Install")
    static let cliReinstall = String(localized: "Reinstall")
    static let cliUninstall = String(localized: "Uninstall")
    static let cliUninstallTitle = String(localized: "Uninstall the command-line tool?")
    static let cliUninstallMessage = String(
        localized: "Scripts and Terminal commands that use Segue will stop working until you install it again.")
    static func cliInstalled(_ path: String) -> String { String(localized: "Installed at \(path)") }
    static func cliStale(_ path: String) -> String { String(localized: "\(path) points to an older copy of Segue.") }
    static func cliFailed(_ message: String) -> String { String(localized: "Couldn't update the command: \(message)") }
    static let cliFooter = String(
        localized:
            "Segue also opens segue:// links, so scripts and other apps can switch input sources, cycle groups, and open the quick switcher."
    )

    static let backupTitle = String(localized: "Settings File")
    static let backupDetail = String(localized: "Save your settings, rules, and shortcuts to a file, or restore them from one.")
    static let importSettings = String(localized: "Import…")
    static let exportSettings = String(localized: "Export…")
    static let exportFileName = String(localized: "Segue Settings.json")
    static let importFailed = String(localized: "Segue couldn't read that settings file.")
    static let exportFailedTitle = String(localized: "Couldn't Export Settings")
    static let importFailedTitle = String(localized: "Couldn't Import Settings")
    static let importConfirmTitle = String(localized: "Replace Your Current Settings?")
    static func importConfirmMessage(_ name: String) -> String {
        String(localized: "Importing “\(name)” replaces your current settings, groups, rules, and shortcuts in Segue.")
    }
    static let importConfirmButton = String(localized: "Replace")
    static func exportedStatus(_ name: String) -> String { String(localized: "Exported to “\(name)”.") }
    static func importedStatus(_ name: String) -> String { String(localized: "Imported settings from “\(name)”.") }
    static let showInFinder = String(localized: "Show in Finder")
    static let loginFailedTitle = String(localized: "Couldn't Change Open at Login")
    static let importNewer = String(localized: "This settings file is from a newer version of Segue. Update Segue and try again.")

    static let kawaTitle = String(localized: "Kawa Shortcuts")
    static let kawaDetail = String(localized: "Bring over the shortcuts you set up in Kawa.")
    static let kawaImport = String(localized: "Import")
    static func kawaImported(_ count: Int) -> String { String(localized: "Imported \(count) shortcuts") }
    static let kawaNothing = String(localized: "No shortcuts found")

    static let sourcesFooter = String(
        localized: "Press a shortcut anywhere to switch to that input source. The label appears in the menu bar and the indicator.")
    static let sourcesManage = String(localized: "Add or remove input sources in Keyboard Settings.")
    static let labelPlaceholder = String(localized: "Label")
    static func labelAccessibility(_ name: String) -> String { String(localized: "Label for \(name)") }
    static func shortcutAccessibility(_ name: String) -> String { String(localized: "Shortcut for \(name)") }

    static let groupsEmptyTitle = String(localized: "No Groups")
    static let groupsEmptyDescription = String(localized: "A group cycles through several input sources with one shortcut.")
    static let addGroup = String(localized: "Add Group")
    static let groupName = String(localized: "Name")
    static func groupDefaultName(_ count: Int) -> String { String(localized: "Group \(count)") }
    static let groupShortcut = String(localized: "Shortcut")
    static let groupAddSource = String(localized: "Add Input Source")
    static func groupRemoveSource(_ name: String) -> String { String(localized: "Remove \(name)") }
    static let removeGroup = String(localized: "Remove Group")
    static func removeTitle(_ name: String) -> String { String(localized: "Remove “\(name)”?") }
    static func removeMemberTitle(_ source: String, _ group: String) -> String { String(localized: "Remove “\(source)” from “\(group)”?") }
    static let removeMemberMessage = String(localized: "The group's shortcut will skip this input source. You can add it back anytime.")
    static let removeConfirm = String(localized: "Remove")
    static let removeGroupMessage = String(localized: "Its shortcut will stop working. You can't undo this.")
    static let cancel = String(localized: "Cancel")
    static let groupNeedsTwo = String(localized: "Add at least two input sources to cycle through.")
    static let groupFooter = String(
        localized:
            "The shortcut switches to the input source you last used in this group, then to the next one each time you press it. Drag to reorder."
    )

    static let quickSwitcherTitle = String(localized: "Quick Switcher")
    static let quickSwitcherDetail = String(
        localized: "Opens a searchable list of your input sources. Press the shortcut again to move down the list.")
    static let switcherPrompt = String(localized: "Switch to…")
    static let switcherSearchAccessibility = String(localized: "Search input sources")
    static let switcherNoResults = String(localized: "No Matching Input Sources")

    static let modifierSection = String(localized: "Modifier Keys")
    static let modifierFooter = String(
        localized: "Tap a modifier key on its own to switch. Holding it or pressing it with another key doesn't count.")
    static let addModifierKey = String(localized: "Add Modifier Key")
    static let removeModifierKey = String(localized: "Remove Modifier Key")
    static let removeModifierMessage = String(localized: "This modifier key will no longer switch input sources.")
    static let modifierKeyLabel = String(localized: "Modifier Key")
    static let modifierGestureLabel = String(localized: "Gesture")
    static let modifierTargetLabel = String(localized: "Action")
    static func modifierRowAccessibility(_ key: String, _ gesture: String) -> String { String(localized: "\(gesture) \(key)") }
    static let gestureTap = String(localized: "Tap")
    static let gestureDoubleTap = String(localized: "Double-Tap")
    static let keyLeftCommand = String(localized: "Left Command (⌘)")
    static let keyRightCommand = String(localized: "Right Command (⌘)")
    static let keyLeftOption = String(localized: "Left Option (⌥)")
    static let keyRightOption = String(localized: "Right Option (⌥)")
    static let keyLeftControl = String(localized: "Left Control (⌃)")
    static let keyRightControl = String(localized: "Right Control (⌃)")
    static let keyLeftShift = String(localized: "Left Shift (⇧)")
    static let keyRightShift = String(localized: "Right Shift (⇧)")
    static let inputMonitoringTitle = String(localized: "Segue can't see modifier keys")
    static let inputMonitoringDetail = String(localized: "Modifier keys need Input Monitoring access in Privacy & Security.")
    static let inputMonitoringAllow = String(localized: "Allow Access…")

    static let conflictsSection = String(localized: "Shortcut Conflicts")
    static let conflictsFooter = String(
        localized: "Only one of these actions runs when you press the shortcut. Change it here or in Keyboard Settings.")
    static func conflictSegue(_ title: String) -> String { String(localized: "Also used for \(title) in Segue") }
    static func conflictSystem(_ title: String) -> String { String(localized: "Also used by macOS for “\(title)”") }
    static func shortcutInUse(_ title: String) -> String { String(localized: "This shortcut is already used for \(title).") }
    static let systemPreviousSource = String(localized: "Select the previous input source")
    static let systemNextSource = String(localized: "Select next source in Input menu")

    static let rememberApps = String(localized: "Remember Input Source for Each App")
    static let rememberAppsDetail = String(
        localized: "When you return to an app, Segue switches back to the input source you last used there.")
    static let appRulesSection = String(localized: "Apps")
    static let appRulesEmpty = String(localized: "No apps yet")
    static let appRulesFooter = String(
        localized:
            "When you switch to one of these apps, Segue switches to its input source. App rules take priority over remembered input sources."
    )
    static let addApp = String(localized: "Add App…")
    static let addAppsTitle = String(localized: "Add Apps")
    static let searchApps = String(localized: "Search Apps")
    static let clearSearch = String(localized: "Clear search")
    static let addSelected = String(localized: "Add")
    static let chooseApp = String(localized: "Choose App…")
    static let websitesSection = String(localized: "Websites")
    static let websiteRulesEmpty = String(localized: "No websites yet")
    static let websitesFooter = String(
        localized:
            "Website rules work in Safari, Chrome, Arc, Brave, Edge, Helium, Vivaldi, and Chromium. They take priority over app rules. A rule for example.com also covers its subdomains."
    )
    static let addWebsite = String(localized: "Add Website")
    static let websiteDomain = String(localized: "Website")
    static let sourceUnavailable = String(localized: "Unavailable Input Source")
    static func ruleSourceAccessibility(_ name: String) -> String { String(localized: "Input source for \(name)") }
    static func removeRule(_ name: String) -> String { String(localized: "Remove rule for \(name)") }
    static func removeRuleTitle(_ name: String) -> String { String(localized: "Remove the rule for “\(name)”?") }
    static let removeAppRuleMessage = String(localized: "Segue will no longer switch input sources when you switch to this app.")
    static let removeWebsiteRuleMessage = String(localized: "Segue will no longer switch input sources on this website.")
    static let removeRuleConfirm = String(localized: "Remove Rule")
    static func automationTitle(_ name: String) -> String { String(localized: "Segue can't see which website is open in \(name)") }
    static let automationDetail = String(localized: "Allow Segue in Privacy & Security > Automation to use website rules.")
    static let automationAllow = String(localized: "Open Privacy Settings")
}
