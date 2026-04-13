import SwiftUI

struct ProtectView: View {
    @StateObject private var viewModel = ProtectViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "shield.checkered",
                color: .green,
                title: "Protect",
                subtitle: "Neutralize threats before they do any harm"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                ProgressView("Scanning for threats...")
                    .padding()
                Spacer()
            } else if viewModel.scanComplete {
                // Status banner
                HStack(spacing: 12) {
                    Image(systemName: viewModel.threats.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.title)
                        .foregroundStyle(viewModel.statusColor)
                    VStack(alignment: .leading) {
                        Text(viewModel.statusMessage)
                            .font(.headline)
                        if !viewModel.threats.isEmpty {
                            Text("\(viewModel.criticalCount) critical · \(viewModel.warningCount) warnings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(viewModel.statusColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()

                if viewModel.threats.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Your Mac is secure")
                            .font(.title3)
                        Button("Scan Again") { Task { await viewModel.scan() } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.threats) { threat in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { threat.isSelected },
                                    set: { _ in viewModel.toggleThreat(threat.id) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Image(systemName: threat.threatType.icon)
                                    .foregroundStyle(threat.severity == .critical ? .red : .orange)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(threat.name)
                                            .font(.body)
                                        Text(threat.threatType.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(threat.severity == .critical ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                    Text(threat.path)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(threat.severity.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(threat.severity == .critical ? .red : .orange)
                            }
                        }
                    }
                    .listStyle(.inset)

                    actionBar(
                        label: "\(viewModel.threats.filter(\.isSelected).count) threat(s) selected",
                        buttonTitle: "Remove",
                        buttonColor: .red,
                        isWorking: viewModel.isRemoving,
                        action: { Task { await viewModel.removeThreats() } }
                    )
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Text("Spot and remove malware that may hide within seemingly innocent software. Stay secure, knowing your Mac is always protected.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    ScanButton(title: "Scan", color: .green) {
                        Task { await viewModel.scan() }
                    }
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
