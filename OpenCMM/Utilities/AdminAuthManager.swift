import SwiftUI
import os

private let logger = Logger(subsystem: "com.opencmm.app", category: "AdminAuth")

/// Manages admin authentication with a native SwiftUI password prompt.
/// Caches credentials for the session so the user doesn't re-enter for every action.
@MainActor
class AdminAuthManager: ObservableObject {
    static let shared = AdminAuthManager()

    @Published var isShowingPrompt = false
    @Published var promptMessage = ""

    private var cachedPassword: String?
    private var pendingAction: ((String) async throws -> Void)?
    private var completion: ((Result<Void, Error>) -> Void)?

    /// Execute a command that requires admin privileges.
    /// Shows a password prompt if credentials aren't cached.
    func withAdmin(
        reason: String,
        action: @escaping (String) async throws -> Void
    ) async throws {
        // If we have a cached password, try it first
        if let password = cachedPassword {
            do {
                try await action(password)
                return
            } catch {
                // Password may have expired or been wrong — clear and re-prompt
                cachedPassword = nil
                logger.info("Cached password failed, re-prompting")
            }
        }

        // Show prompt and wait
        return try await withCheckedThrowingContinuation { cont in
            promptMessage = reason
            pendingAction = action
            completion = { result in cont.resume(with: result) }
            isShowingPrompt = true
        }
    }

    /// Called by the password sheet when the user submits.
    func submitPassword(_ password: String) {
        isShowingPrompt = false
        let action = pendingAction
        let completion = self.completion
        pendingAction = nil
        self.completion = nil

        Task {
            do {
                try await action?(password)
                cachedPassword = password
                logger.info("Admin action succeeded, credentials cached")
                completion?(.success(()))
            } catch {
                logger.warning("Admin action failed: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }

    /// Called by the password sheet when the user cancels.
    func cancelPrompt() {
        isShowingPrompt = false
        let completion = self.completion
        pendingAction = nil
        self.completion = nil
        completion?(.failure(ShellError.failed("Authentication cancelled")))
    }

    /// Clear cached credentials (e.g., on app lock or timeout).
    func clearCredentials() {
        cachedPassword = nil
    }
}
