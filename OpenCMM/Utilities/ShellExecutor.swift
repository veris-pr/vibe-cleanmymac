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

        process.environment = brewEnvironment()

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

    // MARK: - Cancellation-Aware Async Variants

    /// Async version of `run()` that terminates the subprocess when the Swift Task is cancelled.
    @discardableResult
    static func runAsync(_ command: String, arguments: [String] = [], ignoreExitCode: Bool = false) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = brewEnvironment()

        try process.run()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if process.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !ignoreExitCode && process.terminationStatus != 0 {
                        continuation.resume(throwing: ShellError.failed(output.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : output))
                    } else {
                        continuation.resume(returning: output)
                    }
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    /// Async version of `shell()` that terminates the subprocess when the Swift Task is cancelled.
    @discardableResult
    static func shellAsync(_ command: String, ignoreExitCode: Bool = false) async throws -> String {
        try await runAsync("/bin/zsh", arguments: ["-c", command], ignoreExitCode: ignoreExitCode)
    }

    /// Safely quote a path for shell interpolation.
    static func quote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Private

    private static func brewEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let brewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(brewPaths):\(existingPath)"
        } else {
            env["PATH"] = "\(brewPaths):/usr/bin:/bin:/usr/sbin:/sbin"
        }
        return env
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
