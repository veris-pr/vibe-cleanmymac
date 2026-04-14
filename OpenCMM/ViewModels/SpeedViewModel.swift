import SwiftUI

@MainActor
class SpeedViewModel: ObservableObject {
    @Published var loginItems: [LoginItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hostname: String = "Mac"
    @Published var osVersion: String = ""
    @Published var uptime: TimeInterval = 0

    // macmon metrics
    @Published var metrics: SystemMetrics?
    @Published var isMacmonInstalled = false
    @Published var isInstallingMacmon = false
    @Published var installError: String?
    @Published var isMonitoring = false
    @Published var macmonVersion: String?

    // Mole
    @Published var isMoleInstalled = false
    @Published var isInstallingMole = false
    @Published var moleHealthScore: Int?
    @Published var moleHealthMsg: String?
    @Published var moleVersion: String?

    // Optimization
    @Published var isOptimizing = false
    @Published var optimizationComplete = false
    @Published var optimizationSteps: [OptimizationStep] = []

    var scanStore: ScanStore?

    private let service = PerformanceService()
    private let macmonService = MacMonService()
    private let optimizationService = OptimizationService()
    private let moleService = MoleService()
    private let dependencyManager = DependencyManager.shared
    private var monitorTask: Task<Void, Never>?

    func loadData() async {
        isLoading = true
        errorMessage = nil
        loginItems = await service.getLoginItems()
        hostname = Host.current().localizedName ?? "Mac"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        uptime = ProcessInfo.processInfo.systemUptime
        isMacmonInstalled = await dependencyManager.isInstalled(.macmon)
        isMoleInstalled = await dependencyManager.isInstalled(.mole)
        macmonVersion = await dependencyManager.status(for: .macmon).version
        moleVersion = await dependencyManager.status(for: .mole).version

        // Load mole health status if available
        if isMoleInstalled {
            if let moleStatus = await moleService.status() {
                moleHealthScore = moleStatus.healthScore
                moleHealthMsg = moleStatus.healthScoreMsg
            }
        }

        isLoading = false
        updateSummary()

        if isMacmonInstalled {
            startMonitoring()
        }
    }

    func installMacmon() async {
        isInstallingMacmon = true
        installError = nil
        do {
            try await dependencyManager.install(.macmon)
            isMacmonInstalled = true
            startMonitoring()
        } catch {
            installError = error.localizedDescription
        }
        isInstallingMacmon = false
    }

    func installMole() async {
        isInstallingMole = true
        installError = nil
        do {
            try await dependencyManager.install(.mole)
            isMoleInstalled = true
            if let status = await moleService.status() {
                moleHealthScore = status.healthScore
                moleHealthMsg = status.healthScoreMsg
            }
        } catch {
            installError = error.localizedDescription
        }
        isInstallingMole = false
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task {
            while !Task.isCancelled {
                metrics = await macmonService.sample()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        metrics = nil
    }

    func disableLoginItem(_ item: LoginItem) async {
        do {
            try await service.disableLoginItem(path: item.path)
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = false
            }
        } catch {
            errorMessage = "Failed to disable \(item.name): \(error.localizedDescription)"
        }
    }

    func enableLoginItem(_ item: LoginItem) async {
        do {
            try await service.enableLoginItem(path: item.path)
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = true
            }
        } catch {
            errorMessage = "Failed to enable \(item.name): \(error.localizedDescription)"
        }
    }

    private func updateSummary() {
        let issues = loginItems.isEmpty ? [String]() : ["\(loginItems.count) startup item\(loginItems.count == 1 ? "" : "s")"]
        let summary = ModuleScanSummary(
            module: .speed,
            itemCount: loginItems.count,
            totalSize: 0,
            issues: issues,
            timestamp: Date()
        )
        scanStore?.updateSummary(summary)
    }

    // MARK: - Optimization

    func optimize() async {
        isOptimizing = true
        optimizationComplete = false
        errorMessage = nil

        if isMoleInstalled {
            await optimizeWithMole()
        } else {
            await optimizeNative()
        }

        isOptimizing = false
        optimizationComplete = true
    }

    /// Run optimization via Mole CLI — parses output into steps.
    private func optimizeWithMole() async {
        optimizationSteps = [
            OptimizationStep(id: "mole", name: "Mole System Optimize", icon: "bolt.fill", status: .running)
        ]

        do {
            let result = try await moleService.optimize()
            // Parse mole output into individual steps
            let steps = parseMoleOutput(result.output)
            if steps.isEmpty {
                optimizationSteps = [
                    OptimizationStep(
                        id: "mole",
                        name: "Mole System Optimize",
                        icon: "bolt.fill",
                        status: .completed,
                        detail: "\(result.optimizationCount) optimizations applied"
                    )
                ]
            } else {
                optimizationSteps = steps
            }
        } catch {
            optimizationSteps[0].status = .failed
            optimizationSteps[0].detail = error.localizedDescription
        }
    }

    /// Parse `mo optimize` output into discrete steps.
    private func parseMoleOutput(_ output: String) -> [OptimizationStep] {
        var steps: [OptimizationStep] = []
        var currentName: String?
        var currentDetails: [String] = []
        let iconMap: [String: String] = [
            "DNS": "wifi", "Spotlight": "magnifyingglass", "Finder": "eye",
            "App State": "clock.arrow.circlepath", "Broken Config": "wrench",
            "Network": "network", "Database": "cylinder", "LaunchServices": "arrow.triangle.2.circlepath",
            "Font": "textformat", "Dock": "dock.rectangle", "Memory": "memorychip",
            "Permission": "lock.shield", "Bluetooth": "wave.3.right"
        ]

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("➤ ") {
                // Flush previous step
                if let name = currentName {
                    let icon = iconMap.first(where: { name.contains($0.key) })?.value ?? "gear"
                    let detail = currentDetails.joined(separator: "; ")
                    let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
                    steps.append(OptimizationStep(id: id, name: name, icon: icon, status: .completed, detail: detail.isEmpty ? nil : detail))
                }
                currentName = String(trimmed.dropFirst(2))
                currentDetails = []
            } else if trimmed.hasPrefix("→ ") || trimmed.hasPrefix("◎ ") {
                currentDetails.append(String(trimmed.dropFirst(2)))
            }
        }
        // Flush last step
        if let name = currentName {
            let icon = iconMap.first(where: { name.contains($0.key) })?.value ?? "gear"
            let detail = currentDetails.joined(separator: "; ")
            let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
            steps.append(OptimizationStep(id: id, name: name, icon: icon, status: .completed, detail: detail.isEmpty ? nil : detail))
        }

        return steps
    }

    /// Native optimization fallback when Mole is not installed.
    private func optimizeNative() async {
        optimizationSteps = [
            OptimizationStep(id: "launchServices", name: "Rebuild Launch Services", icon: "arrow.triangle.2.circlepath"),
            OptimizationStep(id: "quicklook", name: "Refresh QuickLook Caches", icon: "eye"),
            OptimizationStep(id: "quarantine", name: "Clear Download History", icon: "shield.lefthalf.filled"),
            OptimizationStep(id: "launchAgents", name: "Clean Broken Agents", icon: "gearshape.2"),
            OptimizationStep(id: "preferences", name: "Fix Broken Preferences", icon: "wrench"),
            OptimizationStep(id: "sharedFileLists", name: "Repair Shared File Lists", icon: "list.bullet"),
            OptimizationStep(id: "savedStates", name: "Clean Old Saved States", icon: "clock.arrow.circlepath"),
            OptimizationStep(id: "dsstore", name: "Prevent Network .DS_Store", icon: "network"),
            OptimizationStep(id: "fontCache", name: "Rebuild Font Cache", icon: "textformat"),
            OptimizationStep(id: "appDatabases", name: "Optimize App Databases", icon: "cylinder"),
            OptimizationStep(id: "notifications", name: "Clean Notification Database", icon: "bell.badge"),
            OptimizationStep(id: "coreduet", name: "Optimize Knowledge Database", icon: "brain"),
            OptimizationStep(id: "spotlight", name: "Check Spotlight Index", icon: "magnifyingglass"),
            OptimizationStep(id: "dock", name: "Refresh Dock", icon: "dock.rectangle"),
            OptimizationStep(id: "dns", name: "Flush DNS Cache", icon: "wifi"),
            OptimizationStep(id: "periodic", name: "Run Periodic Maintenance", icon: "calendar.badge.clock"),
            OptimizationStep(id: "permissions", name: "Repair Disk Permissions", icon: "lock.shield"),
            OptimizationStep(id: "memory", name: "Release Memory Pressure", icon: "memorychip"),
            OptimizationStep(id: "networkStack", name: "Flush Network Stack", icon: "antenna.radiowaves.left.and.right"),
        ]

        for i in optimizationSteps.indices {
            optimizationSteps[i].status = .running
            do {
                let result: OptimizationService.StepResult
                switch optimizationSteps[i].id {
                case "launchServices":
                    result = try await optimizationService.rebuildLaunchServices()
                case "quicklook":
                    result = try await optimizationService.refreshQuickLookCaches()
                case "quarantine":
                    result = try await optimizationService.clearQuarantineHistory()
                case "launchAgents":
                    result = try await optimizationService.cleanBrokenLaunchAgents()
                case "preferences":
                    result = try await optimizationService.fixBrokenPreferences()
                case "sharedFileLists":
                    result = try await optimizationService.repairSharedFileLists()
                case "savedStates":
                    result = try await optimizationService.cleanOldSavedStates()
                case "dsstore":
                    result = try await optimizationService.preventNetworkDSStore()
                case "fontCache":
                    result = try await optimizationService.rebuildFontCache()
                case "appDatabases":
                    result = try await optimizationService.vacuumAppDatabases()
                case "notifications":
                    result = try await optimizationService.cleanNotificationDatabase()
                case "coreduet":
                    result = try await optimizationService.cleanCoreDuetDatabase()
                case "spotlight":
                    result = try await optimizationService.optimizeSpotlightIndex()
                case "dock":
                    result = try await optimizationService.refreshDock()
                case "dns":
                    result = try await optimizationService.flushDNSCache()
                case "periodic":
                    result = try await optimizationService.runPeriodicMaintenance()
                case "permissions":
                    result = try await optimizationService.repairDiskPermissions()
                case "memory":
                    result = try await optimizationService.purgeMemory()
                case "networkStack":
                    result = try await optimizationService.flushNetworkStack()
                default:
                    continue
                }
                optimizationSteps[i].status = .completed
                optimizationSteps[i].detail = result.detail
            } catch {
                optimizationSteps[i].status = .failed
                optimizationSteps[i].detail = error.localizedDescription
            }
        }
    }
}
