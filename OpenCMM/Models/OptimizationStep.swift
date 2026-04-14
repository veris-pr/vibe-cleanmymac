import Foundation

struct OptimizationStep: Identifiable {
    let id: String
    let name: String
    let icon: String
    var status: StepStatus = .pending
    var detail: String?

    enum StepStatus {
        case pending, running, completed, failed
    }
}
