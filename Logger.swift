// Lightweight file logger for debugging the menu bar app.
// GUI apps have no attached terminal, so we append to a logfile we can `tail`.
// Log location: ~/.config/flick.log

import Foundation

enum Log {
    private static let logURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("flick.log")
    }()

    static func write(_ message: String) {
        let line = "\(timestamp()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            // File doesn't exist yet, create it
            try? data.write(to: logURL)
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
