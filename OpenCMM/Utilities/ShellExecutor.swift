import Foundation

enum ShellExecutor {
    @discardableResult
    static func run(_ command: String, arguments: [String] = [], ignoreExitCode: Bool = false) throws -> String {
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

        // Read pipe BEFORE waitUntilExit to prevent deadlock.
        // If the process output fills the pipe buffer (~64KB), the process
        // blocks on write. Reading first drains the buffer and lets it finish.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !ignoreExitCode && process.terminationStatus != 0 {
            throw ShellError.failed(output.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : output)
        }

        return output
    }

    @discardableResult
    static func shell(_ command: String, ignoreExitCode: Bool = false) throws -> String {
        try run("/bin/zsh", arguments: ["-c", command], ignoreExitCode: ignoreExitCode)
    }

    /// Run a command with sudo, piping the password via stdin.
    /// No osascript, no random permission dialogs.
    @discardableResult
    static func shellWithSudo(_ command: String, password: String) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "sudo -S \(command) 2>&1"]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.standardInput = inputPipe

        var env = ProcessInfo.processInfo.environment
        let brewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(brewPaths):\(existingPath)"
        } else {
            env["PATH"] = "\(brewPaths):/usr/bin:/bin:/usr/sbin:/sbin"
        }
        process.environment = env

        try process.run()

        // Feed password to sudo via stdin
        if let data = "\(password)\n".data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
        inputPipe.fileHandleForWriting.closeFile()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        var output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Filter out sudo's password prompt from output
        output = output.components(separatedBy: "\n")
            .filter { !$0.contains("Password:") && !$0.contains("Sorry, try again") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            if output.contains("incorrect password") || output.contains("Sorry, try again") {
                throw ShellError.failed("Incorrect password")
            }
            throw ShellError.failed(output.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : output)
        }

        return output
    }

    /// Safely quote a path for shell interpolation.
    static func quote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
