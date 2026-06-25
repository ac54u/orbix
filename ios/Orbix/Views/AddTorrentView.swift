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
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        modePicker

                        Group {
                            if mode == .link {
                                linkInputSection
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            } else {
                                fileInputSection
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }
                        }

                        optionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("添加种子")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                Task { @MainActor in
                    handleFileSelection(result)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        } else {
                            Text("添加")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
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

    private var modePicker: some View {
        Picker("添加方式", selection: $mode.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
            ForEach(AddMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    private var linkInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Magnet / URL")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $linkText)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 160)

                if linkText.isEmpty {
                    Text("输入 magnet 链接或 URL，每行一个")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.placeholder)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private var fileInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("种子文件")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            if let url = selectedFileURL {
                HStack(spacing: 16) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                            .lineLimit(1)
                        Text("准备上传")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.success)
                    }

                    Spacer()

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFileURL = nil
                            selectedFileData = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                Button {
                    pickFile()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.accent)
                        Text("点击选择 .torrent 文件")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.card.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                                .foregroundColor(AppColors.tertiaryLabel)
                        )
                )
                .contentShape(Rectangle())
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("高级选项")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                IconTextFieldRow(icon: "square.grid.2x2.fill", placeholder: "分类", text: $category)
                Divider().padding(.leading, 44)
                IconTextFieldRow(icon: "tag.fill", placeholder: "标签 (逗号分隔)", text: $tags)
                Divider().padding(.leading, 44)
                IconTextFieldRow(icon: "folder.fill", placeholder: "保存路径", text: $savePath, disableAutocap: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .link: return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return selectedFileData != nil
        }
    }

    private func submit() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
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

                let successImpact = UINotificationFeedbackGenerator()
                successImpact.notificationOccurred(.success)

                await MainActor.run { dismiss() }
            } catch {
                let errorImpact = UINotificationFeedbackGenerator()
                errorImpact.notificationOccurred(.error)

                await MainActor.run { isSubmitting = false }
            }
        }
    }

    private func pickFile() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        showFilePicker = true
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedFileURL = url
                    selectedFileData = data
                }
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
            }
        case .failure(let error):
            print(error.localizedDescription)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
        }
    }
}

// MARK: - 辅助组件

private struct IconTextFieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var disableAutocap: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.label)
                .textInputAutocapitalization(disableAutocap ? .never : .sentences)
                .disableAutocorrection(disableAutocap)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
