import AppKit
import KeyboardShortcuts

final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var visibilityObservation: NSKeyValueObservation?

    override init() {
        super.init()
        item.autosaveName = "Segue"
        item.behavior = .removalAllowed
        menu.delegate = self
        item.button?.target = self
        item.button?.action = #selector(showMenu(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        visibilityObservation = item.observe(\.isVisible) { item, _ in
            let visible = item.isVisible
            MainActor.assumeIsolated {
                if Preferences.shared.showInMenuBar != visible { Preferences.shared.showInMenuBar = visible }
            }
        }
        trackChanges { [weak self] in self?.refresh() }
    }

    private func refresh() {
        let prefs = Preferences.shared
        item.isVisible = prefs.showInMenuBar
        guard let button = item.button else { return }
        guard let source = Switcher.shared.current else {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Segue")
            return
        }
        let image: NSImage =
            switch prefs.menuBarStyle {
            case .label: MenuBarIcon.badge(prefs.label(for: source))
            case .icon: source.icon.statusSized
            }
        image.accessibilityDescription = L.menuBarAccessibility(source.name)
        button.image = image
        button.toolTip = source.name
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let switcher = Switcher.shared
        if switcher.sources.isEmpty {
            let empty = NSMenuItem(title: L.noSources, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for source in switcher.sources {
            let entry = NSMenuItem(title: source.name, action: #selector(selectSource(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = source.id
            entry.image = source.icon.menuSized
            entry.state = source == switcher.current ? .on : .off
            entry.setShortcut(KeyboardShortcuts.getShortcut(for: .source(source.id)))
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(action(L.openKeyboardSettings, #selector(openKeyboardSettings), symbol: "keyboard"))
        menu.addItem(.separator())
        if KeyboardShortcuts.getShortcut(for: .quickSwitcher) != nil || !Preferences.shared.modifierTriggers.isEmpty {
            let quick = action(L.quickSwitcherMenu, #selector(openQuickSwitcher), symbol: "magnifyingglass")
            quick.setShortcut(for: .quickSwitcher)
            menu.addItem(quick)
        }
        menu.addItem(action(L.settingsMenu, #selector(openSettings), symbol: "gearshape", key: ","))
        if Updater.shared.isAvailable {
            let update = NSMenuItem(title: L.checkForUpdatesMenu, action: #selector(Updater.checkForUpdates(_:)), keyEquivalent: "")
            update.target = Updater.shared
            update.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            menu.addItem(update)
        }
        let quit = NSMenuItem(title: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quit)
        for entry in menu.items {
            entry.preferredImageVisibility = .visible
        }
    }

    @objc private func showMenu(_ button: NSStatusBarButton) {
        guard let window = button.window, let screen = window.screen else { return }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let barBottom = screen.visibleFrame.maxY < screen.frame.maxY ? screen.visibleFrame.maxY : 2 * frame.midY - screen.frame.maxY
        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: frame.minX - 5, y: barBottom - 6), in: nil)
        button.highlight(false)
    }

    func menuWillOpen(_: NSMenu) {
        KeyboardShortcuts.isEnabled = false
    }

    func menuDidClose(_: NSMenu) {
        KeyboardShortcuts.isEnabled = true
    }

    private func action(_ title: String, _ selector: Selector, symbol: String, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        entry.target = self
        entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return entry
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let source = Switcher.shared.source(id) else { return }
        Switcher.shared.select(source)
    }

    @objc private func openKeyboardSettings() {
        KeyboardSettings.open()
    }

    @objc private func openQuickSwitcher() {
        QuickSwitcher.shared.show()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }
}

enum KeyboardSettings {
    static func open() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum MenuBarIcon {
    static func badge(_ text: String) -> NSImage {
        let font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        let attributes: Dictionary<NSAttributedString.Key, Any> = [.font: font, .foregroundColor: NSColor.black]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let height: CGFloat = 15
        let width = max(height + 4, ceil(textSize.width) + 9)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let frame = rect.insetBy(dx: 0.75, dy: 0.75)
            let outline = NSBezierPath(roundedRect: frame, xRadius: 3.5, yRadius: 3.5)
            outline.lineWidth = 1.3
            NSColor.black.setStroke()
            outline.stroke()
            string.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2 + 0.25))
            return true
        }
        image.isTemplate = true
        return image
    }
}

extension NSImage {
    var menuSized: NSImage { fitted(trailing: 6) }

    var statusSized: NSImage { fitted(trailing: nil) }

    private func fitted(trailing: CGFloat?) -> NSImage {
        let source = self
        let ink = inkBounds
        let box = NSSize(width: 22, height: 16)
        let scale = min(box.width / max(ink.width, 1), box.height / max(ink.height, 1))
        let size = NSSize(width: ink.width * scale, height: ink.height * scale)
        let canvas = trailing.map { NSSize(width: box.width + $0, height: box.height) } ?? size
        let image = NSImage(size: canvas, flipped: false) { rect in
            let x = trailing == nil ? 0 : box.width - size.width
            let frame = NSRect(x: x, y: rect.midY - size.height / 2, width: size.width, height: size.height)
            source.draw(in: frame, from: ink, operation: .sourceOver, fraction: 1)
            return true
        }
        image.isTemplate = isTemplate
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private var inkBounds: NSRect {
        let full = NSRect(origin: .zero, size: size)
        guard let bitmap = representations.compactMap({ $0 as? NSBitmapImageRep }).max(by: { $0.pixelsWide < $1.pixelsWide }) else {
            return full
        }
        var minX = Int.max
        var minY = Int.max
        var maxX = -1
        var maxY = -1
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return full }
        let scaleX = size.width / CGFloat(bitmap.pixelsWide)
        let scaleY = size.height / CGFloat(bitmap.pixelsHigh)
        return NSRect(
            x: CGFloat(minX) * scaleX, y: size.height - CGFloat(maxY + 1) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX, height: CGFloat(maxY - minY + 1) * scaleY)
    }
}
