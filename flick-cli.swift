// flick CLI: toggle services and check status from the command line.
// Configuration: ~/.config/flick.json
//
// NOTE: Service/AppConfig/loadConfig are duplicated from Config.swift because
// the CLI and the menu bar app build as separate binaries. Keep them in sync.

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

struct Flick {
    private let config: AppConfig

    init() {
        self.config = loadConfig()
    }

    func run(_ command: String = "") {
        let args = command.split(separator: " ").map(String.init)

        if args.isEmpty {
            printAllServices()
        } else {
            let serviceId = String(args[0])
            let operation = args.count > 1 ? String(args[1]) : "toggle"

            guard let service = config.services.first(where: { $0.id == serviceId }) else {
                print("Error: Unknown service '\(serviceId)'")
                listServices()
                exit(1)
            }

            performOperation(operation, on: service)
        }
    }

    private func printAllServices() {
        print("Services:")
        for service in config.services {
            let status = checkStatus(service.statusCommand) ? "✓ " : "○ "
            print("  \(status)\(service.name) (\(service.id))")
        }
        print("\nUsage: flick <service_id> [status|toggle|connect|disconnect]")
    }

    private func listServices() {
        print("\nAvailable services:")
        for service in config.services {
            print("  - \(service.id): \(service.name)")
        }
    }

    private func performOperation(_ operation: String, on service: Service) {
        switch operation {
        case "status":
            let isConnected = checkStatus(service.statusCommand)
            print(isConnected ? "connected" : "disconnected")
        case "toggle", "":
            toggle(service)
        case "connect":
            executeCommand(service.connectCommand)
        case "disconnect":
            executeCommand(service.disconnectCommand)
        default:
            print("Unknown operation: \(operation)")
            exit(1)
        }
    }

    private func toggle(_ service: Service) {
        if checkStatus(service.statusCommand) {
            print("Disconnecting \(service.name)...")
            executeCommand(service.disconnectCommand)
            print("\(service.name) disconnected")
        } else {
            print("Connecting \(service.name)...")
            executeCommand(service.connectCommand)
            sleep(2)
            if checkStatus(service.statusCommand) {
                print("\(service.name) connected")
            } else {
                print("Failed to connect \(service.name)")
                exit(1)
            }
        }
    }

    private func checkStatus(_ command: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func executeCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error executing command: \(error)")
            exit(1)
        }
    }
}

let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1..<CommandLine.arguments.count].joined(separator: " ") : ""
Flick().run(command)
