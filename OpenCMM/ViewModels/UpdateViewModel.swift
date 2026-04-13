import SwiftUI

@MainActor
class UpdateViewModel: ObservableObject {
    @Published var updates: [AppUpdateInfo] = []
    @Published var isChecking = false
    @Published var isUpdating = false
    @Published var checkComplete = false

    private let service = UpdateService()

    var updateCount: Int { updates.count }
    var selectedCount: Int { updates.filter(\.isSelected).count }

    func checkForUpdates() async {
        isChecking = true
        checkComplete = false
        updates = await service.checkForUpdates()
        isChecking = false
        checkComplete = true
    }

    func updateSelected() async {
        isUpdating = true
        let selected = updates.filter(\.isSelected)
        for app in selected {
            let success = await service.updateApp(app)
            if success {
                updates.removeAll { $0.id == app.id }
            }
        }
        isUpdating = false
    }

    func updateSingle(_ app: AppUpdateInfo) async {
        let success = await service.updateApp(app)
        if success {
            updates.removeAll { $0.id == app.id }
        }
    }

    func toggleApp(_ id: UUID) {
        if let index = updates.firstIndex(where: { $0.id == id }) {
            updates[index].isSelected.toggle()
        }
    }
}
