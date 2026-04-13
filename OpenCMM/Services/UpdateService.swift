import Foundation

actor UpdateService {
    func checkForUpdates() async -> [AppUpdateInfo] {
        var updates: [AppUpdateInfo] = []

        // Check Homebrew formulae
        if let brewUpdates = await checkHomebrewUpdates() {
            updates.append(contentsOf: brewUpdates)
        }

        // Check Homebrew casks
        if let caskUpdates = await checkHomebrewCaskUpdates() {
            updates.append(contentsOf: caskUpdates)
        }

        return updates
    }

    func updateApp(_ app: AppUpdateInfo) async -> Bool {
        do {
            switch app.source {
            case .homebrew:
                try ShellExecutor.shell("brew upgrade \(app.name)")
            case .homebrewCask:
                try ShellExecutor.shell("brew upgrade --cask \(app.name)")
            case .appStore:
                // App Store updates handled by MasService
                return false
            case .manual:
                return false
            }
            return true
        } catch {
            print("Failed to update \(app.name): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    private func checkHomebrewUpdates() async -> [AppUpdateInfo]? {
        guard isHomebrewInstalled() else { return nil }

        do {
            let output = try ShellExecutor.shell("brew outdated --json")
            guard let data = output.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }

            return json.compactMap { item -> AppUpdateInfo? in
                guard let name = item["name"] as? String,
                      let currentVersion = item["installed_versions"] as? [String],
                      let availableVersion = item["current_version"] as? String else {
                    return nil
                }
                return AppUpdateInfo(
                    name: name,
                    currentVersion: currentVersion.first ?? "unknown",
                    availableVersion: availableVersion,
                    source: .homebrew
                )
            }
        } catch {
            return nil
        }
    }

    private func checkHomebrewCaskUpdates() async -> [AppUpdateInfo]? {
        guard isHomebrewInstalled() else { return nil }

        do {
            let output = try ShellExecutor.shell("brew outdated --cask --greedy --json")
            guard let data = output.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }

            return json.compactMap { item -> AppUpdateInfo? in
                guard let name = item["name"] as? String,
                      let currentVersion = item["installed_versions"] as? [String],
                      let availableVersion = item["current_version"] as? String else {
                    return nil
                }
                return AppUpdateInfo(
                    name: name,
                    currentVersion: currentVersion.first ?? "unknown",
                    availableVersion: availableVersion,
                    source: .homebrewCask
                )
            }
        } catch {
            return nil
        }
    }

    private func isHomebrewInstalled() -> Bool {
        FileUtils.exists("/opt/homebrew/bin/brew") || FileUtils.exists("/usr/local/bin/brew")
    }
}
