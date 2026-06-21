// flick — menu bar app. A colored dot shows aggregate service status.
// Click = open menu, Alt+click = quit. Global hotkeys toggle services.

import SwiftUI
import AppKit

@main
struct FlickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var viewModel: ServicesModel?
    var hotkeyManager: HotkeyManager?
    var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = ServicesModel()
        setupStatusBar()
        setupGlobalHotkeys()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)

        guard let button = statusItem?.button else { return }

        updateIcon(button)

        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startIconUpdates()
        }
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApplication.shared.currentEvent
        let flags = event?.modifierFlags ?? []

        if flags.contains(.option) {
            NSApplication.shared.terminate(nil)
        } else {
            showStatusMenu()
        }
    }

    private func startIconUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if let button = self?.statusItem?.button {
                self?.updateIcon(button)
            }
            self?.updateStatusMenu()
        }
    }

    private func updateIcon(_ button: NSStatusBarButton) {
        guard let viewModel = viewModel else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)

        // Determine overall state
        let isLoading = viewModel.services.contains { $0.isLoading }
        let allConnected = viewModel.services.allSatisfy { $0.isConnected }
        let anyConnected = viewModel.services.contains { $0.isConnected }

        // Choose symbol and color
        let symbolName: String
        let color: NSColor

        if isLoading {
            // Loading state: transparent
            button.appearsDisabled = true
            symbolName = "circle.fill"
            let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            button.image = baseImage
            return
        }

        button.appearsDisabled = false

        if allConnected {
            // All connected: filled green circle
            symbolName = "circle.fill"
            color = .systemGreen
        } else if anyConnected {
            // Some connected: filled yellow circle
            symbolName = "circle.fill"
            color = .systemYellow
        } else {
            // None connected: empty circle (ring)
            symbolName = "circle"
            color = .lightGray
        }

        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        let tinted = baseImage.tinted(with: color)
        button.image = tinted
    }

    private func updateStatusMenu() {
        guard let menu = statusMenu, let viewModel = viewModel else { return }

        for (index, item) in menu.items.enumerated() {
            if index < viewModel.services.count {
                updateMenuItemTitle(item, state: viewModel.services[index])
            }
        }
    }

    private func setupGlobalHotkeys() {
        guard let viewModel = viewModel, let config = viewModel.config else {
            Log.write("setupGlobalHotkeys: no viewModel/config, aborting")
            return
        }

        let manager = HotkeyManager()
        hotkeyManager = manager

        // Menu hotkey (to show service menu)
        let menuKey = config.menuHotkeyKey ?? "space"
        let menuMods = config.menuHotkeyModifiers ?? ["cmd", "opt"]
        manager.register(key: menuKey, modifiers: menuMods) { [weak self] in
            self?.showStatusMenu()
        }

        // Per-service hotkeys
        for service in config.services {
            let serviceId = service.id
            manager.register(key: service.hotkeyKey, modifiers: service.hotkeyModifiers) { [weak self] in
                self?.viewModel?.toggle(serviceId: serviceId)
            }
        }
    }

    private func showStatusMenu() {
        guard let statusItem = statusItem else { return }
        statusMenu = createStatusMenu()
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
    }

    private func createStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 200

        guard let viewModel = viewModel else { return menu }

        // Add service items with enhanced styling
        for state in viewModel.services {
            let item = NSMenuItem(title: "", action: #selector(toggleService(_:)), keyEquivalent: "")
            item.representedObject = state.id
            updateMenuItemTitle(item, state: state)

            // Add visual spacing and styling
            item.attributedTitle = createAttributedMenuTitle(for: state)

            menu.addItem(item)
        }

        if !viewModel.services.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        // Quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.attributedTitle = NSAttributedString(
            string: "Quit",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(quitItem)

        return menu
    }

    private func createAttributedMenuTitle(for state: ServiceState) -> NSAttributedString {
        let statusIcon: String
        let statusColor: NSColor

        if state.isLoading {
            statusIcon = "⟳"
            statusColor = .systemOrange
        } else if state.isConnected {
            statusIcon = "●"
            statusColor = .systemGreen
        } else {
            statusIcon = "○"
            statusColor = .secondaryLabelColor
        }

        let mutableString = NSMutableAttributedString()

        // Status icon with color
        let iconString = NSAttributedString(
            string: statusIcon,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: statusColor
            ]
        )
        mutableString.append(iconString)

        // Spacing
        mutableString.append(NSAttributedString(string: "  "))

        // Service name
        let nameString = NSAttributedString(
            string: state.name,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )
        mutableString.append(nameString)

        return mutableString
    }

    private func updateMenuItemTitle(_ item: NSMenuItem, state: ServiceState) {
        item.attributedTitle = createAttributedMenuTitle(for: state)
    }

    @objc func toggleService(_ sender: NSMenuItem) {
        guard let serviceId = sender.representedObject as? String else { return }
        viewModel?.toggle(serviceId: serviceId)
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        // SF Symbols default to isTemplate = true, which makes the status bar
        // render them monochrome and discard our color. Turn it off so the
        // green/yellow tint actually shows.
        image.isTemplate = false
        return image
    }
}
