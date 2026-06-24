import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss

    enum AddMode: String, CaseIterable {
        case link = "链接"
        case file = "文件"
    }

    @State private var mode: AddMode = .link
    @State private var linkText = ""
    @State private var selectedFileURL: URL?
    @State private var selectedFileData: Data?
    @State private var category = ""
    @State private var tags = ""
    @State private var savePath = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            List {
                Picker("添加方式", selection: $mode) {
                    ForEach(AddMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(AppColors.card)

                switch mode {
                case .link:
                    Section {
                        TextEditor(text: $linkText)
                            .bodyFont()
                            .frame(minHeight: 120)
                            .overlay(alignment: .topLeading) {
                                if linkText.isEmpty {
                                    Text("输入 magnet 链接或 URL，每行一个")
                                        .subtitle(AppColors.placeholder)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            }
                    } header: {
                        Text("Magnet / URL")
                    }

                case .file:
                    Section {
                        Button {
                            pickFile()
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(AppColors.accent)
                                Text("选择 .torrent 文件")
                                    .bodyFont()
                                Spacer()
                                if selectedFileURL != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                }
                            }
                        }

                        if let url = selectedFileURL {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(AppColors.secondaryLabel)
                                Text(url.lastPathComponent)
                                    .subtitle()
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    selectedFileURL = nil
                                    selectedFileData = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.tertiaryLabel)
                                }
                            }
                        }
                    }
                }

                Section("选项（可选）") {
                    TextField("分类", text: $category)
                        .bodyFont()
                    TextField("标签（逗号分隔）", text: $tags)
                        .bodyFont()
                    TextField("保存路径", text: $savePath)
                        .bodyFont()
                        .autocapitalization(.none)
                }
            }
            .insetGroupedStyle()
            .navigationTitle("添加种子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { submit() }
                        .disabled(!canSubmit || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ConnectingDialog(message: "添加中...")
                }
            }
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .link: return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return selectedFileData != nil
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                switch mode {
                case .link:
                    let urls = linkText
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    let _ = try await QBitApi.shared.addMagnet(
                        urls,
                        category: category.isEmpty ? nil : category,
                        tags: tags.isEmpty ? nil : tags,
                        savePath: savePath.isEmpty ? nil : savePath
                    )
                case .file:
                    if let data = selectedFileData, let url = selectedFileURL {
                        let _ = try await QBitApi.shared.addTorrent(
                            bytes: data,
                            filename: url.lastPathComponent,
                            category: category.isEmpty ? nil : category,
                            tags: tags.isEmpty ? nil : tags,
                            savePath: savePath.isEmpty ? nil : savePath
                        )
                    }
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { isSubmitting = false }
            }
        }
    }

    private func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "torrent") ?? .data])
        // Would need UIViewControllerRepresentable for SwiftUI
    }
}
