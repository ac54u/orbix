import SwiftUI

struct TorrentDetailView: View {
    let hash: String

    @Environment(\.dismiss) private var dismiss
    @State private var torrent: TorrentInfo?
    @State private var properties: TorrentProperties?
    @State private var files: [TorrentFile] = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppColors.groupedBg.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    SkeletonBar(height: 56)
                    SkeletonBar(height: 12)
                    SkeletonBar(height: 12)
                    SkeletonBar(height: 12)
                }
                .padding(.horizontal, 20)
            } else if let torrent = torrent {
                List {
                    heroSection(torrent)

                    if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                        errorHint(torrent.errorString)
                    }

                    actionButtons(torrent)

                    transferSection(torrent)

                    if let props = properties {
                        infoSection(props)
                    }

                    if !files.isEmpty {
                        filesSection
                    }
                }
                .insetGroupedStyle()
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
    private func heroSection(_ torrent: TorrentInfo) -> some View {
        Section {
            VStack(spacing: 12) {
                Text(torrent.name)
                    .cardTitle()
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("\(torrent.progressPercent)%")
                    .hero(AppColors.accent)

                HStack(spacing: 16) {
                    Label(torrent.statusBadge.displayName, systemImage: "circle.fill")
                        .caption(statusColor(torrent))
                    SpeedBadge(speed: torrent.dlspeed)
                        .foregroundColor(AppColors.accent)
                    Text("↓")
                        .caption()
                    SpeedBadge(speed: torrent.upspeed)
                        .foregroundColor(AppColors.success)
                    Text("↑")
                        .caption()
                }

                ProgressBar(progress: torrent.progress, color: progressColor(torrent))
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(AppColors.card)
        }
    }

    private func errorHint(_ message: String) -> some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.warning)
                Text(message)
                    .subtitle(AppColors.warning)
            }
            .padding(.vertical, 4)
            .listRowBackground(AppColors.warning.opacity(0.1))
        }
    }

    private func actionButtons(_ torrent: TorrentInfo) -> some View {
        Section {
            HStack(spacing: 8) {
                ActionButton(
                    icon: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill",
                    label: torrent.statusBadge.isPaused ? "开始" : "暂停",
                    action: { togglePause(torrent) }
                )
                ActionButton(
                    icon: "bolt.fill",
                    label: "强制",
                    action: { forceStart(torrent) }
                )
                ActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: "校验",
                    action: { recheck(torrent) }
                )
                ActionButton(
                    icon: "arrow.clockwise",
                    label: "重新通告",
                    action: { reannounce(torrent) }
                )
            }
            .listRowBackground(AppColors.card)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private func transferSection(_ torrent: TorrentInfo) -> some View {
        Section("传输") {
            DetailRow(label: "下载速度", value: formattedSpeed(torrent.dlspeed), color: AppColors.accent)
            DetailRow(label: "上传速度", value: formattedSpeed(torrent.upspeed), color: AppColors.success)
            DetailRow(label: "已下载", value: formattedSize(torrent.downloaded))
            DetailRow(label: "已上传", value: formattedSize(torrent.uploaded))
            DetailRow(label: "分享率", value: String(format: "%.2f", torrent.ratio))
            if torrent.eta > 0 {
                DetailRow(label: "预计完成", value: torrent.etaFormatted)
            }
            DetailRow(label: "种子数", value: "\(torrent.numSeeds) / \(torrent.numLeechs)")
        }
    }

    private func infoSection(_ props: TorrentProperties) -> some View {
        Section("信息") {
            DetailRow(label: "总大小", value: formattedSize(props.totalSize))
            DetailRow(label: "保存路径", value: props.savePath)
                .font(.system(size: 13, design: .monospaced))
            if !props.category.isEmpty {
                DetailRow(label: "分类", value: props.category)
            }
            if !props.tags.isEmpty {
                DetailRow(label: "标签", value: props.tags)
            }
            DetailRow(label: "Hash", value: props.hash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.tertiaryLabel)
        }
    }

    private var filesSection: some View {
        Section("文件") {
            ForEach(files) { file in
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .subtitle()
                        .lineLimit(1)
                    HStack {
                        ProgressBar(progress: file.progress, height: 2)
                            .frame(width: 100)
                        Text("\(file.progressPercent)%")
                            .caption()
                        Spacer()
                        Text(formattedSize(file.size))
                            .caption()
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(AppColors.card)
            }
        }
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

    private func togglePause(_ torrent: TorrentInfo) {
        Task {
            if torrent.statusBadge.isPaused {
                try? await QBitApi.shared.startTorrent(hash)
            } else {
                try? await QBitApi.shared.stopTorrent(hash)
            }
        }
    }

    private func forceStart(_ torrent: TorrentInfo) {
        Task { try? await QBitApi.shared.forceStartTorrent(hash) }
    }

    private func recheck(_ torrent: TorrentInfo) {
        Task { try? await QBitApi.shared.recheckTorrent(hash) }
    }

    private func reannounce(_ torrent: TorrentInfo) {
        Task { try? await QBitApi.shared.reannounceTorrent(hash) }
    }

    private func delete(_ deleteFiles: Bool) {
        Task {
            try? await QBitApi.shared.deleteTorrent(hash, deleteFiles: deleteFiles)
            dismiss()
        }
    }

    private func statusColor(_ torrent: TorrentInfo) -> Color {
        switch torrent.statusBadge {
        case .uploading, .stalledUP: return AppColors.success
        case .downloading, .metaDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        default: return AppColors.secondaryLabel
        }
    }

    private func progressColor(_ torrent: TorrentInfo) -> Color {
        if torrent.statusBadge.isError { return AppColors.danger }
        return torrent.isCompleted ? AppColors.success : AppColors.accent
    }

    private func formattedSpeed(_ speed: Int64) -> String {
        if speed >= 1_000_000 { return String(format: "%.1f MB/s", Double(speed) / 1_000_000) }
        if speed >= 1_000 { return String(format: "%.1f KB/s", Double(speed) / 1_000) }
        return "\(speed) B/s"
    }

    private func formattedSize(_ bytes: Int64) -> String {
        if bytes >= 1_000_000_000 { return String(format: "%.2f GB", Double(bytes) / 1_000_000_000) }
        if bytes >= 1_000_000 { return String(format: "%.2f MB", Double(bytes) / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.2f KB", Double(bytes) / 1_000) }
        return "\(bytes) B"
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .caption()
            }
            .foregroundColor(AppColors.label)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.elevated)
            )
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var color: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .subtitle()
            Spacer()
            Text(value)
                .bodyFont(color.map { $0 } ?? AppColors.label)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
        .listRowBackground(AppColors.card)
    }
}
