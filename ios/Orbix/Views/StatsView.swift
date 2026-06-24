import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        SkeletonBar(height: 56, width: 200)
                        SkeletonBar(height: 12)
                        SkeletonBar(height: 12)
                        SkeletonBar(height: 12)
                        SkeletonBar(height: 12)
                    }
                    .padding(.horizontal, 20)
                } else {
                    List {
                        heroSpeedSection

                        transferVolumeSection

                        connectionSection

                        diskSection

                        overviewSection
                    }
                    .insetGroupedStyle()
                }
            }
            .navigationTitle("Stats")
            .onAppear { refresh() }
            .onReceive(timer) { _ in refresh() }
        }
    }

    private var heroSpeedSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("当前总速度")
                    .sectionHeader()

                HStack(alignment: .firstBaseline, spacing: 4) {
                    Text(formattedHeroSpeed)
                        .hero(AppColors.accent)
                    Text("B/s")
                        .subtitle(AppColors.tertiaryLabel)
                }

                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                        SpeedBadge(speed: transfer?.dlInfoSpeed ?? 0)
                            .foregroundColor(AppColors.accent)
                        Text("↓")
                            .caption(AppColors.tertiaryLabel)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 8, height: 8)
                        SpeedBadge(speed: transfer?.upInfoSpeed ?? 0)
                            .foregroundColor(AppColors.success)
                        Text("↑")
                            .caption(AppColors.tertiaryLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(AppColors.card)
        }
    }

    private var transferVolumeSection: some View {
        Section("传输量") {
            if let state = transfer?.serverState {
                DetailStatRow(label: "会话下载", value: formattedSize(state.alltimeDl))
                DetailStatRow(label: "会话上传", value: formattedSize(state.alltimeUl))
                DetailStatRow(label: "总计下载", value: formattedSize(transfer?.dlInfoData ?? 0))
                DetailStatRow(label: "总计上传", value: formattedSize(transfer?.upInfoData ?? 0))
                DetailStatRow(label: "全局分享率", value: state.globalRatio ?? "-")
                DetailStatRow(label: "浪费", value: formattedSize(state.totalWastedSession))
            }
        }
    }

    private var connectionSection: some View {
        Section("连接") {
            if let state = transfer?.serverState {
                HStack {
                    Text("状态")
                        .subtitle()
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(connectionColor(state.connectionStatus))
                            .frame(width: 8, height: 8)
                        Text(state.connectionStatus.capitalized)
                            .bodyFont(connectionColor(state.connectionStatus))
                    }
                }
                DetailStatRow(label: "DHT 节点", value: "\(state.dhtNodes)")
            }
        }
    }

    private var diskSection: some View {
        Section("磁盘") {
            if let state = transfer?.serverState {
                DetailStatRow(label: "可用空间", value: formattedSize(state.freeSpaceOnDisk))
            }
        }
    }

    private var overviewSection: some View {
        Section("概览") {
            let total = torrents.count
            let downloading = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
            let seeding = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
            let paused = torrents.filter { $0.statusBadge.isPaused }.count
            let checking = torrents.filter { $0.statusBadge == .checkingDL || $0.statusBadge == .checkingUP }.count
            let errored = torrents.filter { $0.statusBadge.isError }.count

            OverviewRow(icon: "square.stack", label: "总计", count: total, color: AppColors.label)
            OverviewRow(icon: "arrow.down.circle", label: "下载中", count: downloading, color: AppColors.accent)
            OverviewRow(icon: "arrow.up.circle", label: "做种中", count: seeding, color: AppColors.success)
            OverviewRow(icon: "pause.circle", label: "已暂停", count: paused, color: AppColors.tertiaryLabel)
            OverviewRow(icon: "arrow.triangle.2.circlepath", label: "检查中", count: checking, color: AppColors.warning)
            OverviewRow(icon: "exclamationmark.circle", label: "错误", count: errored, color: AppColors.danger)
        }
    }

    private var formattedHeroSpeed: String {
        let total = (transfer?.dlInfoSpeed ?? 0) + (transfer?.upInfoSpeed ?? 0)
        if total >= 1_000_000 { return String(format: "%.1f M", Double(total) / 1_000_000) }
        if total >= 1_000 { return String(format: "%.1f K", Double(total) / 1_000) }
        return "\(total)"
    }

    private func connectionColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "connected": return AppColors.success
        case "firewalled": return AppColors.warning
        default: return AppColors.danger
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        if bytes >= 1_000_000_000 { return String(format: "%.2f GB", Double(bytes) / 1_000_000_000) }
        if bytes >= 1_000_000 { return String(format: "%.2f MB", Double(bytes) / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.2f KB", Double(bytes) / 1_000) }
        return "\(bytes) B"
    }

    private func refresh() {
        Task {
            do {
                let t = try await QBitApi.shared.getTransferInfo()
                let list = try await QBitApi.shared.getTorrents()
                await MainActor.run {
                    transfer = t
                    torrents = list
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

private struct DetailStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .subtitle()
            Spacer()
            Text(value)
                .bodyFont()
        }
        .listRowBackground(AppColors.card)
    }
}

private struct OverviewRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .subtitle()
            Spacer()
            Text("\(count)")
                .bodyFont(color)
        }
        .listRowBackground(AppColors.card)
    }
}
