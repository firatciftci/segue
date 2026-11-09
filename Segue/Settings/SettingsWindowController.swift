import AppKit
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general
    case sources
    case groups
    case shortcuts
    case apps

    init?(name: String) {
        guard let tab = Self.allCases.first(where: { "\($0)".caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        self = tab
    }
}

private final class SettingsTabs: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {
        super.tabView(tabView, didSelect: item)
        if view.window?.isVisible == true {
            Preferences.store.set(selectedTabViewItemIndex, forKey: "settingsTab")
        }
        Task { [weak self] in self?.view.window?.makeFirstResponder(nil) }
    }
}

private final class DemoWindow: NSWindow {
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func hasMainAppearance() -> Bool { true }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let tabs: SettingsTabs
    private var restoredTab: Int?
    private var activation: Task<Void, Never>?

    private init() {
        restoredTab = Preferences.store.integer(forKey: "settingsTab")
        let tabs = SettingsTabs()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        func add(_ title: String, symbol: String, _ pane: some View) {
            let host = NSHostingController(
                rootView:
                    pane
                    .environment(Preferences.shared)
                    .environment(Switcher.shared)
                    .environment(AutoSwitcher.shared)
                    .environment(ModifierTaps.shared)
                    .environment(ShortcutAudit.shared)
                    .environment(CommandLineTool.shared)
                    .environment(Updater.shared)
                    .frame(width: 560)
                    .fixedSize(horizontal: false, vertical: true))
            host.sizingOptions = .preferredContentSize
            host.title = title
            let item = NSTabViewItem(viewController: host)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add(L.tabGeneral, symbol: "gearshape", GeneralPane())
        add(L.tabSources, symbol: "keyboard", SourcesPane())
        add(L.tabGroups, symbol: "square.stack", GroupsPane())
        add(L.tabShortcuts, symbol: "command", ShortcutsPane())
        add(L.tabApps, symbol: "square.grid.2x2", AppsPane())
        let window = DemoData.isEnabled ? DemoWindow(contentViewController: tabs) : NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Settings")
        self.tabs = tabs
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { nil }

    func show(_ tab: SettingsTab? = nil) {
        guard let window else { return }
        let index = tab?.rawValue ?? restoredTab
        restoredTab = nil
        if Preferences.shared.showInDock, NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        if let index { tabs.selectedTabViewItemIndex = min(index, tabs.tabViewItems.count - 1) }
        window.collectionBehavior.insert(.moveToActiveSpace)
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !NSApp.isActive { window.level = .floating }
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(nil)
        activation?.cancel()
        activation = Task { [weak self] in
            for _ in 0..<20 {
                if NSApp.isActive, window.isKeyWindow || window.attachedSheet?.isKeyWindow == true { break }
                Self.activate()
                if window.attachedSheet == nil { window.makeKeyAndOrderFront(nil) }
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
            }
            self?.settle()
        }
    }

    private static func activate() {
        if let front = NSWorkspace.shared.frontmostApplication, front != NSRunningApplication.current {
            _ = NSRunningApplication.current.activate(from: front)
        }
        NSApp.activate()
    }

    private func settle() {
        guard NSApp.isActive, let window, window.level != .normal else { return }
        window.level = .normal
    }

    func windowDidBecomeKey(_: Notification) {
        settle()
    }

    func updateDockIcon() {
        guard let window, window.isVisible else { return }
        NSApp.setActivationPolicy(Preferences.shared.showInDock ? .regular : .accessory)
        Self.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_: Notification) {
        activation?.cancel()
        window?.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }
}
