import SwiftUI

struct UpdateView: View {
    @StateObject private var viewModel = UpdateViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "arrow.triangle.2.circlepath",
                color: .cyan,
                title: "Update",
                subtitle: "Keep your apps up to date"
            )

            Divider()

            if viewModel.isChecking {
                Spacer()
                ProgressView("Checking for updates...")
                Spacer()
            } else if viewModel.checkComplete {
                if viewModel.updates.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("All apps are up to date")
                            .font(.title3)
                        Button("Check Again") { Task { await viewModel.checkForUpdates() } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.updates) { app in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { app.isSelected },
                                    set: { _ in viewModel.toggleApp(app.id) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Image(systemName: "app.fill")
                                    .font(.title2)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.body.bold())
                                    Text("\(app.currentVersion) → \(app.availableVersion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(app.source.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())

                                Button("Update") {
                                    Task { await viewModel.updateSingle(app) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)

                    actionBar(
                        label: "\(viewModel.selectedCount) of \(viewModel.updateCount) selected",
                        buttonTitle: "Update All",
                        buttonColor: .cyan,
                        isWorking: viewModel.isUpdating,
                        action: { Task { await viewModel.updateSelected() } }
                    )
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Text("Stopped using an app? Update all your software right here to improve app security and stability.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    ScanButton(title: "Check for Updates", color: .cyan) {
                        Task { await viewModel.checkForUpdates() }
                    }
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
