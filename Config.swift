// Configuration loading from ~/.config/flick.json
// Supports multiple services with per-service hotkeys.
//
// NOTE: This file is compiled into both the menu bar app and the `flick` CLI
// (they build as separate binaries), so Service/AppConfig/loadConfig are
// intentionally duplicated in flick-cli.swift. Keep the two in sync.

import Foundation

struct Service: Codable, Identifiable {
    let id: String
    let name: String
    let statusCommand: String
    let connectCommand: String
    let disconnectCommand: String
    let hotkeyKey: String
    let hotkeyModifiers: [String]

    enum CodingKeys: String, CodingKey {
        case id, name
        case statusCommand = "status_command"
        case connectCommand = "connect_command"
        case disconnectCommand = "disconnect_command"
        case hotkeyKey = "hotkey_key"
        case hotkeyModifiers = "hotkey_modifiers"
    }
}

struct AppConfig: Codable {
    let services: [Service]
    let menuHotkeyKey: String?
    let menuHotkeyModifiers: [String]?

    enum CodingKeys: String, CodingKey {
        case services
        case menuHotkeyKey = "menu_hotkey_key"
        case menuHotkeyModifiers = "menu_hotkey_modifiers"
    }
}

func loadConfig() -> AppConfig {
    let fileManager = FileManager.default
    let homeDir = fileManager.homeDirectoryForCurrentUser
    let configDir = homeDir.appendingPathComponent(".config", isDirectory: true)
    let configFile = configDir.appendingPathComponent("flick.json")

    // Create .config directory if it doesn't exist
    if !fileManager.fileExists(atPath: configDir.path) {
        do {
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating .config directory: \(error)")
        }
    }

    // If config file doesn't exist, create template
    if !fileManager.fileExists(atPath: configFile.path) {
        let template = """
        {
          "menu_hotkey_key": "space",
          "menu_hotkey_modifiers": ["cmd", "opt"],
          "services": [
            {
              "id": "openvpn",
              "name": "OpenVPN",
              "status_command": "pgrep -x openvpn",
              "connect_command": "sudo /opt/homebrew/sbin/openvpn --config /path/to/your/config.ovpn --daemon",
              "disconnect_command": "sudo killall openvpn",
              "hotkey_key": "v",
              "hotkey_modifiers": ["cmd", "opt"]
            }
          ]
        }
        """
        do {
            try template.write(to: configFile, atomically: true, encoding: .utf8)
            print("Created config template: \(configFile.path)")
            print("Please edit it to add your services")
        } catch {
            print("Error creating config file: \(error)")
        }
    }

    // Load and validate config
    do {
        let data = try Data(contentsOf: configFile)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        if config.services.isEmpty {
            print("Error: No services configured in \(configFile.path)")
            exit(1)
        }

        return config
    } catch {
        print("Error loading config from \(configFile.path): \(error)")
        exit(1)
    }
}
