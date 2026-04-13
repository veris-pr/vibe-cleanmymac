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

        // Inherit Homebrew PATH so brew commands work from GUI apps
        var env = ProcessInfo.processInfo.environment
        let brewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(brewPaths):\(existingPath)"
        } else {
            env["PATH"] = "\(brewPaths):/usr/bin:/bin:/usr/sbin:/sbin"
        }
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 && !output.isEmpty {
            throw ShellError.failed(output)
        }

        return output
    }

    @discardableResult
    static func shell(_ command: String) throws -> String {
        try run("/bin/zsh", arguments: ["-c", command])
    }

    /// Run a command with admin privileges via macOS authorization prompt.
    @discardableResult
    static func shellWithAdmin(_ command: String) throws -> String {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return try run("/usr/bin/osascript", arguments: ["-e", script])
    }
}

enum ShellError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let output):
            // Return just the last meaningful line
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            return lines.last ?? "Command failed"
        }
    }
}
