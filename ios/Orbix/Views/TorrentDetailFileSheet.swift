import SwiftUI

struct TorrentDetailFileSheet: View {
    let hash: String
    let files: [TorrentFile]
    @Binding var selectedFileIndices: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    HStack(spacing: 10) {
                        Image(systemName: selectedFileIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFileIndices.contains(index) ? AppColors.accent : AppColors.tertiaryLabel)
                            .onTapGesture {
                                if selectedFileIndices.contains(index) {
                                    selectedFileIndices.remove(index)
                                } else {
                                    selectedFileIndices.insert(index)
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)
                            Text(formatBytes(file.size))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.secondaryLabel)
                        }

                        Spacer()

                        priorityBadge(file.priority)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("文件优先级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss(); selectedFileIndices = [] }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedFileIndices.isEmpty {
                        Menu {
                            Button { setPrio(0) } label: { Label("忽略", systemImage: "nosign") }
                            Button { setPrio(1) } label: { Label("正常", systemImage: "minus") }
                            Button { setPrio(6) } label: { Label("高", systemImage: "arrow.up") }
                            Button { setPrio(7) } label: { Label("最高", systemImage: "arrow.up.to.line") }
                        } label: {
                            Text("批量 (\(selectedFileIndices.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    Button("完成") { dismiss(); selectedFileIndices = [] }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func priorityBadge(_ priority: Int) -> some View {
        let (label, color): (String, Color) = {
            switch priority {
            case 0: return ("忽略", AppColors.secondaryLabel)
            case 6: return ("高", AppColors.accent)
            case 7: return ("最高", AppColors.success)
            default: return ("正常", AppColors.tertiaryLabel)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.12))
            )
    }

    private func setPrio(_ priority: Int) {
        let indices = Array(selectedFileIndices)
        Task {
            try? await QBitApi.shared.setFilePriorities(hash, indices: indices, priority: priority)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            _ = try? await QBitApi.shared.getTorrentFiles(hash)
            await MainActor.run {
                selectedFileIndices = []
            }
        }
    }
}
