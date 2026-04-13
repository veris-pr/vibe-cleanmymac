import Foundation

enum ShellExecutor {
    @discardableResult
    static func run(_ command: String, arguments: [String] = []) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @discardableResult
    static func shell(_ command: String) throws -> String {
        try run("/bin/zsh", arguments: ["-c", command])
    }
}
