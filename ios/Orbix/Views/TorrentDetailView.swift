import SwiftUI

struct TorrentDetailView: View {
    let hash: String

    @Environment(\.dismiss) private var dismiss
    @State private var torrent: TorrentInfo?
    @State private var properties: TorrentProperties?
    @State private var files: [TorrentFile] = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true
    @State private var processingAction: ActionType? = nil

    enum ActionType {
        case pause, force, recheck, announce
    }

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    SkeletonBar(height: 140)
                    SkeletonBar(height: 80)
                    SkeletonBar(height: 200)
                }
                .padding(20)
            } else if let torrent = torrent {
                ScrollView {
                    VStack(spacing: 20) {
                        dashboardCard(torrent)

                        if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                            errorHint(torrent.errorString)
                        }

                        actionGrid(torrent)

                        VStack(spacing: 16) {
                            transferSection(torrent)
                            if let props = properties {
                                infoSection(props)
                            }
                        }

                        if !files.isEmpty {
                            filesSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await manualRefresh()
                }
            }
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.danger)
                }
            }
        }
        .alert("删除种子", isPresented: $showDeleteConfirmation) {
            Button("仅删除任务", role: .destructive) {
                delete(false)
            }
            Button("删除任务及文件", role: .destructive) {
                delete(true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除此种子吗？")
        }
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    @ViewBuilder
    private func dashboardCard(_ torrent: TorrentInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(torrent.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.label)
                .lineLimit(3)

            HStack(alignment: .bottom) {
                Text("\(torrent.progressPercent)%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(progressColor(torrent))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(torrent))
                            .frame(width: 8, height: 8)
                        Text(torrent.statusBadge.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(statusColor(torrent))
                    }

                    if torrent.dlspeed > 0 {
                        Text("↓ \(formatSpeed(torrent.dlspeed))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.accent)
                    } else if torrent.upspeed > 0 {
                        Text("↑ \(formatSpeed(torrent.upspeed))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.success)
                    }
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.separator.opacity(0.5))
                    Capsule()
                        .fill(progressColor(torrent))
                        .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                }
            }
            .frame(height: 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [progressColor(torrent).opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func actionGrid(_ torrent: TorrentInfo) -> some View {
        HStack(spacing: 12) {
            ActionTile(
                icon: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill",
                label: torrent.statusBadge.isPaused ? "启动" : "暂停",
                color: torrent.statusBadge.isPaused ? AppColors.success : AppColors.warning,
                isLoading: processingAction == .pause,
                action: { performAction(.pause, torrent: torrent) }
            )
            ActionTile(
                icon: "bolt.fill",
                label: "强制",
                color: AppColors.accent,
                isLoading: processingAction == .force,
                action: { performAction(.force, torrent: torrent) }
            )
            ActionTile(
                icon: "checkmark.shield.fill",
                label: "校验",
                color: AppColors.accent,
                isLoading: processingAction == .recheck,
                action: { performAction(.recheck, torrent: torrent) }
            )
            ActionTile(
                icon: "antenna.radiowaves.left.and.right",
                label: "汇报",
                color: AppColors.accent,
                isLoading: processingAction == .announce,
                action: { performAction(.announce, torrent: torrent) }
            )
        }
    }

    private func transferSection(_ torrent: TorrentInfo) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: "传输")
            VStack(spacing: 0) {
                DetailRow(icon: "arrow.down.circle.fill", iconColor: AppColors.accent, label: "下载速度", value: formatSpeed(torrent.dlspeed), valueColor: AppColors.accent)
                Divider().padding(.leading, 44)
                DetailRow(icon: "arrow.up.circle.fill", iconColor: AppColors.success, label: "上传速度", value: formatSpeed(torrent.upspeed), valueColor: AppColors.success)
                Divider().padding(.leading, 44)
                DetailRow(icon: "tray.and.arrow.down.fill", iconColor: AppColors.secondaryLabel, label: "已下载", value: formatBytes(torrent.downloaded))
                Divider().padding(.leading, 44)
                DetailRow(icon: "tray.and.arrow.up.fill", iconColor: AppColors.secondaryLabel, label: "已上传", value: formatBytes(torrent.uploaded))
                Divider().padding(.leading, 44)
                DetailRow(icon: "chart.pie.fill", iconColor: AppColors.secondaryLabel, label: "分享率", value: String(format: "%.2f", torrent.ratio), valueColor: torrent.ratio >= 1.0 ? AppColors.success : AppColors.secondaryLabel)
                if torrent.eta > 0 {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "timer", iconColor: AppColors.secondaryLabel, label: "预计完成", value: torrent.etaFormatted)
                }
                Divider().padding(.leading, 44)
                DetailRow(icon: "person.2.fill", iconColor: AppColors.secondaryLabel, label: "种子/吸血", value: "\(torrent.numSeeds) / \(torrent.numLeechs)")
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private func infoSection(_ props: TorrentProperties) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: "信息")
            VStack(spacing: 0) {
                DetailRow(icon: "internaldrive.fill", iconColor: AppColors.secondaryLabel, label: "总大小", value: formatBytes(props.totalSize))
                Divider().padding(.leading, 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 24)
                        Text("保存路径")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        CopyButton(textToCopy: props.savePath)
                    }
                    Text(props.savePath)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                        .lineLimit(2)
                        .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !props.category.isEmpty {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "square.grid.2x2.fill", iconColor: AppColors.secondaryLabel, label: "分类", value: props.category)
                }
                if !props.tags.isEmpty {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "tag.fill", iconColor: AppColors.secondaryLabel, label: "标签", value: props.tags)
                }

                Divider().padding(.leading, 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 24)
                        Text("Hash")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        CopyButton(textToCopy: props.hash)
                    }
                    Text(props.hash)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private var filesSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "文件 (\(files.count))")
            VStack(spacing: 0) {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    HStack(spacing: 12) {
                        Image(systemName: iconForFile(filename: file.name))
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(file.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)

                            HStack {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppColors.separator.opacity(0.5))
                                        Capsule()
                                            .fill(AppColors.accent)
                                            .frame(width: max(0, geometry.size.width * CGFloat(file.progress)))
                                    }
                                }
                                .frame(height: 3)
                                .frame(maxWidth: 80)

                                Text("\(file.progressPercent)%")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppColors.secondaryLabel)

                                Spacer()

                                Text(formatBytes(file.size))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < files.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private func iconForFile(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "ts": return "film.fill"
        case "mp3", "flac", "wav", "aac", "m4a", "ogg": return "music.note"
        case "jpg", "jpeg", "png", "gif", "webp", "heic": return "photo.fill"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "txt", "md", "csv", "json", "xml", "nfo": return "doc.text.fill"
        case "pdf": return "doc.richtext.fill"
        case "exe", "msi", "dmg", "pkg", "apk", "ipa": return "app.badge.fill"
        case "iso": return "opticaldisc"
        default: return "doc.fill"
        }
    }

    private func errorHint(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.danger)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.danger)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.danger.opacity(0.1))
        .cornerRadius(12)
    }

    private func statusColor(_ torrent: TorrentInfo) -> Color {
        switch torrent.statusBadge {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }

    private func progressColor(_ torrent: TorrentInfo) -> Color {
        if torrent.statusBadge.isError { return AppColors.danger }
        return torrent.isCompleted ? AppColors.success : AppColors.accent
    }

    private func refresh() {
        Task {
            do {
                let t = try await QBitApi.shared.getTorrentByHash(hash)
                let p = try await QBitApi.shared.getProperties(hash)
                let f = try await QBitApi.shared.getTorrentFiles(hash)
                await MainActor.run {
                    torrent = t
                    properties = p
                    files = f
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    @Sendable private func manualRefresh() async {
        let t = try? await QBitApi.shared.getTorrentByHash(hash)
        let p = try? await QBitApi.shared.getProperties(hash)
        let f = try? await QBitApi.shared.getTorrentFiles(hash)
        await MainActor.run {
            if let t = t { torrent = t }
            if let p = p { properties = p }
            if let f = f { files = f }
        }
    }

    private func performAction(_ type: ActionType, torrent: TorrentInfo) {
        guard processingAction == nil else { return }
        processingAction = type

        Task {
            do {
                switch type {
                case .pause:
                    if torrent.statusBadge.isPaused {
                        try await QBitApi.shared.startTorrent(hash)
                    } else {
                        try await QBitApi.shared.stopTorrent(hash)
                    }
                case .force:
                    try await QBitApi.shared.forceStartTorrent(hash)
                case .recheck:
                    try await QBitApi.shared.recheckTorrent(hash)
                case .announce:
                    try await QBitApi.shared.reannounceTorrent(hash)
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await manualRefresh()
            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }

            await MainActor.run {
                processingAction = nil
            }
        }
    }

    private func delete(_ deleteFiles: Bool) {
        Task {
            try? await QBitApi.shared.deleteTorrent(hash, deleteFiles: deleteFiles)
            dismiss()
        }
    }
}

// MARK: - 辅助组件

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColors.secondaryLabel)
            .textCase(.uppercase)
            .padding(.leading, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color = AppColors.secondaryLabel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.label)
            Spacer()
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct CopyButton: View {
    let textToCopy: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = textToCopy
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: 14))
                .foregroundColor(copied ? AppColors.success : AppColors.accent)
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                action()
            }
        }) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                        .frame(height: 20)
                }

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
    }
}


