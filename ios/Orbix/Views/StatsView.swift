import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        SkeletonBar(height: 80)
                        SkeletonBar(height: 80)
                        SkeletonBar(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Text("当前总速度").sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            heroSpeedCard

                            Text("传输量").sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            transferVolumeCard

                            Text("连接").sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            connectionCard

                            Text("磁盘").sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            diskCard

                            Text("概览").sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            overviewCard

                            Color.clear.frame(height: 80)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("传输统计")
            .onAppear { refresh() }
            .onReceive(timer) { _ in refresh() }
        }
    }

    // MARK: - Hero Speed Card
    private var heroSpeedCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedHeroSpeed)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.accent)
                Text("B/s")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.tertiaryLabel)
            }

            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                    Text(formatSpeed(transfer?.dlInfoSpeed ?? 0))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                    Text("↓")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                    Text(formatSpeed(transfer?.upInfoSpeed ?? 0))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.success)
                    Text("↑")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Transfer Volume Card
    private var transferVolumeCard: some View {
        VStack(spacing: 0) {
            if let state = transfer?.serverState {
                statRow("会话下载", value: formatBytes(transfer?.dlInfoData ?? 0))
                Divider().background(AppColors.separator)
                statRow("会话上传", value: formatBytes(transfer?.upInfoData ?? 0))
                Divider().background(AppColors.separator)
                statRow("总计下载", value: formatBytes(state.alltimeDl))
                Divider().background(AppColors.separator)
                statRow("总计上传", value: formatBytes(state.alltimeUl))
                Divider().background(AppColors.separator)
                statRow("全局分享率", value: state.globalRatio ?? "-")
                Divider().background(AppColors.separator)
                statRow("浪费", value: formatBytes(state.totalWastedSession))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Connection Card
    private var connectionCard: some View {
        VStack(spacing: 0) {
            if let state = transfer?.serverState {
                connectionStatusRow(status: state.connectionStatus)
                Divider().background(AppColors.separator)
                statRow("DHT 节点", value: "\(state.dhtNodes)")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Disk Card
    private var diskCard: some View {
        VStack(spacing: 0) {
            if let state = transfer?.serverState {
                statRow("可用空间", value: formatBytes(state.freeSpaceOnDisk))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Overview Card
    private var overviewCard: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let checking = torrents.filter { $0.statusBadge == .checkingDL || $0.statusBadge == .checkingUP }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count

        return VStack(spacing: 0) {
            overviewRow("square.stack", "总计", torrents.count, AppColors.label)
            Divider().background(AppColors.separator)
            overviewRow("arrow.down.circle", "下载中", dl, AppColors.accent)
            Divider().background(AppColors.separator)
            overviewRow("arrow.up.circle", "做种中", up, AppColors.success)
            Divider().background(AppColors.separator)
            overviewRow("pause.circle", "已暂停", paused, AppColors.tertiaryLabel)
            Divider().background(AppColors.separator)
            overviewRow("arrow.triangle.2.circlepath", "检查中", checking, AppColors.warning)
            Divider().background(AppColors.separator)
            overviewRow("exclamationmark.circle", "错误", errored, AppColors.danger)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Row Helpers
    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.label)
        }
        .padding(.vertical, 10)
    }

    private func connectionStatusRow(status: String) -> some View {
        HStack {
            Text("状态")
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionColor(status))
                    .frame(width: 8, height: 8)
                Text(status.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(connectionColor(status))
            }
        }
        .padding(.vertical, 10)
    }

    private func overviewRow(_ icon: String, _ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Data
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
