import SwiftUI

struct DeclutterView: View {
    @StateObject private var viewModel = DeclutterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "square.on.square.dashed",
                color: .pink,
                title: "Declutter",
                subtitle: "Take control of the clutter"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                ProgressView("Scanning for duplicates and large files...")
                Spacer()
            } else if viewModel.scanComplete {
                // Tab picker
                Picker("", selection: $viewModel.selectedTab) {
                    ForEach(DeclutterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch viewModel.selectedTab {
                case .duplicates:
                    duplicatesView
                case .largeFiles:
                    largeFilesView
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Text("Curb the file chaos by removing duplicates and similar photos. Find large and forgotten items to ensure you always have enough space.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    ScanButton(title: "Scan", color: .pink) {
                        Task { await viewModel.scan() }
                    }
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var duplicatesView: some View {
        Group {
            if viewModel.duplicateGroups.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No duplicates found")
                        .font(.title3)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.duplicateGroups) { group in
                        Section {
                            ForEach(group.files) { file in
                                HStack {
                                    Image(systemName: file.keepThis ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(file.keepThis ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.body)
                                        Text(file.path)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(Formatters.fileSize(file.size))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            HStack {
                                Text("\(group.files.count) duplicates")
                                    .font(.headline)
                                Spacer()
                                Text("Wasted: \(Formatters.fileSize(group.wastedSpace))")
                                    .font(.subheadline)
                                    .foregroundStyle(.pink)
                            }
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "Wasted space: \(Formatters.fileSize(viewModel.totalWastedSpace))",
                    buttonTitle: "Remove Duplicates",
                    buttonColor: .pink,
                    isWorking: viewModel.isRemoving,
                    action: { Task { await viewModel.removeDuplicates() } }
                )
            }
        }
    }

    private var largeFilesView: some View {
        Group {
            if viewModel.largeFiles.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No large files found")
                        .font(.title3)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.largeFiles) { file in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { file.isSelected },
                                set: { _ in viewModel.toggleLargeFile(file.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(systemName: "doc.fill")
                                .foregroundStyle(.pink)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.body)
                                HStack {
                                    Text(file.path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("·")
                                    Text("Last used \(Formatters.relativeDate(file.lastAccessed))")
                                }
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(Formatters.fileSize(file.size))
                                .font(.body.monospacedDigit().bold())
                                .foregroundStyle(.pink)
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalLargeFilesSize)) selected",
                    buttonTitle: "Move to Trash",
                    buttonColor: .pink,
                    isWorking: viewModel.isRemoving,
                    action: { Task { await viewModel.removeLargeFiles() } }
                )
            }
        }
    }
}
