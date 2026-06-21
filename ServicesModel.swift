// Service state tracking and management.
//
// Plain class on purpose: the UI is pure AppKit and refreshes on a Timer poll
// (see AppDelegate), so nothing observes this via SwiftUI. Avoiding the
// @Observable macro also keeps the build working under the Command Line Tools
// Swift toolchain (which Homebrew uses), where the macro can fail to expand.

import Foundation

final class ServicesModel {
    private(set) var services: [ServiceState] = []
    private(set) var config: AppConfig?

    init() {
        self.config = loadConfig()
        updateServices()
        startStatusMonitoring()
    }

    func toggle(serviceId: String) {
        guard let index = services.firstIndex(where: { $0.id == serviceId }),
              let service = config?.services.first(where: { $0.id == serviceId }) else { return }

        Task {
            services[index].isLoading = true
            do {
                if services[index].isConnected {
                    try executeCommand(service.disconnectCommand)
                } else {
                    try executeCommand(service.connectCommand)
                }
                try await Task.sleep(nanoseconds: 2_000_000_000)
                updateServiceStatus(serviceId: serviceId, service: service)
            } catch {
                print("Toggle failed: \(error)")
            }
            services[index].isLoading = false
        }
    }

    private func updateServices() {
        guard let config = config else { return }
        services = config.services.map { service in
            ServiceState(id: service.id, name: service.name, isConnected: false, isLoading: false)
        }
        for service in config.services {
            updateServiceStatus(serviceId: service.id, service: service)
        }
    }

    private func updateServiceStatus(serviceId: String, service: Service) {
        guard let index = services.firstIndex(where: { $0.id == serviceId }) else { return }
        do {
            services[index].isConnected = try checkStatus(service.statusCommand)
        } catch {
            print("Status check failed for \(serviceId): \(error)")
        }
    }

    private func startStatusMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let config = self.config else { return }
            for service in config.services {
                self.updateServiceStatus(serviceId: service.id, service: service)
            }
        }
    }

    private func checkStatus(_ command: String) throws -> Bool {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        try task.run()
        task.waitUntilExit()

        return task.terminationStatus == 0
    }

    private func executeCommand(_ command: String) throws {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        try task.run()
        task.waitUntilExit()
    }
}

struct ServiceState: Identifiable {
    let id: String
    let name: String
    var isConnected: Bool
    var isLoading: Bool
}
