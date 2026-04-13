import Foundation

/// Integrates osquery for deep system auditing.
/// Queries launch daemons, listening ports, browser extensions, firewall status.
actor OsqueryService {
    private let deps = DependencyManager.shared

    struct AuditResult {
        var launchItems: [LaunchItemAudit] = []
        var listeningPorts: [ListeningPort] = []
        var browserExtensions: [BrowserExtension] = []
        var firewallEnabled: Bool = false
        var sipEnabled: Bool = true
    }

    struct LaunchItemAudit: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let programPath: String
        let runAtLoad: Bool
        let isApple: Bool
    }

    struct ListeningPort: Identifiable {
        let id = UUID()
        let port: Int
        let protocol_: String
        let processName: String
        let pid: Int
    }

    struct BrowserExtension: Identifiable {
        let id = UUID()
        let name: String
        let identifier: String
        let browser: String
        let version: String
    }

    var isAvailable: Bool {
        get async { await deps.isInstalled(.osquery) }
    }

    func audit() async -> AuditResult? {
        guard let osqueryi = await deps.path(for: .osquery) else { return nil }
        var result = AuditResult()

        // Launch items (non-Apple)
        if let json = query(osqueryi, sql: "SELECT name, path, program, run_at_load FROM launchd WHERE name NOT LIKE 'com.apple%' LIMIT 100") {
            result.launchItems = json.compactMap { row in
                guard let name = row["name"] as? String else { return nil }
                return LaunchItemAudit(
                    name: name,
                    path: row["path"] as? String ?? "",
                    programPath: row["program"] as? String ?? "",
                    runAtLoad: (row["run_at_load"] as? String) == "1",
                    isApple: name.hasPrefix("com.apple")
                )
            }
        }

        // Listening ports
        if let json = query(osqueryi, sql: "SELECT l.port, l.protocol, p.name as process_name, l.pid FROM listening_ports l LEFT JOIN processes p ON l.pid = p.pid WHERE l.port > 0 ORDER BY l.port LIMIT 50") {
            result.listeningPorts = json.compactMap { row in
                guard let portStr = row["port"] as? String, let port = Int(portStr) else { return nil }
                return ListeningPort(
                    port: port,
                    protocol_: row["protocol"] as? String ?? "tcp",
                    processName: row["process_name"] as? String ?? "unknown",
                    pid: Int(row["pid"] as? String ?? "0") ?? 0
                )
            }
        }

        // Safari extensions
        if let json = query(osqueryi, sql: "SELECT name, identifier, version FROM safari_extensions LIMIT 50") {
            result.browserExtensions = json.compactMap { row in
                guard let name = row["name"] as? String else { return nil }
                return BrowserExtension(
                    name: name,
                    identifier: row["identifier"] as? String ?? "",
                    browser: "Safari",
                    version: row["version"] as? String ?? ""
                )
            }
        }

        // Firewall status
        if let json = query(osqueryi, sql: "SELECT global_state FROM alf LIMIT 1"),
           let first = json.first,
           let state = first["global_state"] as? String {
            result.firewallEnabled = state != "0"
        }

        // SIP status
        if let json = query(osqueryi, sql: "SELECT enabled FROM sip_config WHERE config_flag='sip' LIMIT 1"),
           let first = json.first,
           let enabled = first["enabled"] as? String {
            result.sipEnabled = enabled == "1"
        }

        return result
    }

    private func query(_ osqueryi: String, sql: String) -> [[String: Any]]? {
        guard let output = try? ShellExecutor.shell("\(osqueryi) --json \"\(sql)\""),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return json
    }
}
