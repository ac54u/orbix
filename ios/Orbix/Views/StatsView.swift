import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true
    @State private var serverVersion: String = ""
    @State private var refreshSuppressed = false
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                if !isLoading {
                    serverSection
                    historySection
                    sessionSection
                    serverInfoSection
                    torrentStatusSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.groupedBg)
            .navigationTitle(OrbixStrings.navTransferStats)
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard !refreshSuppressed else { return }
                refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                refreshSuppressed = phase != .active
            }
        }
    }

    // MARK: - Server
    private var serverSection: some View {
        Section {
            HStack {
                Text("qBittorrent")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.label)
                Spacer()
                Text(serverVersion.isEmpty ? "—" : serverVersion)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppColors.label)
            }
        } header: {
            Text(String(localized: "服务器", comment: "Server").uppercased())
        }
    }

    // MARK: - History Stats
    private var historySection: some View {
        let s = transfer?.serverState
        return Section {
            statRow(icon: "arrow.down.circle.fill", color: AppColors.accent,
                    label: String(localized: "总下载量", comment: "Total downloaded"),
                    value: s.flatMap { formatBytes($0.alltimeDl) } ?? "—")

            statRow(icon: "arrow.up.circle.fill", color: AppColors.success,
                    label: String(localized: "总上传量", comment: "Total uploaded"),
                    value: s.flatMap { formatBytes($0.alltimeUl) } ?? "—")

            statRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.warning,
                    label: String(localized: "分享率", comment: "Ratio"),
                    value: s?.globalRatio ?? "—")
        } header: {
            Text(String(localized: "历史统计", comment: "History stats").uppercased())
        }
    }

    // MARK: - Current Session
    private var sessionSection: some View {
        let t = transfer
        let s = transfer?.serverState
        return Section {
            statRow(icon: "arrow.down", color: AppColors.accent,
                    label: String(localized: "下载速度", comment: "Download speed"),
                    value: t.flatMap { formatSpeed($0.dlInfoSpeed) } ?? "0 B/s",
                    monospaced: true)

            statRow(icon: "arrow.up", color: AppColors.success,
                    label: String(localized: "上传速度", comment: "Upload speed"),
                    value: t.flatMap { formatSpeed($0.upInfoSpeed) } ?? "0 B/s",
                    monospaced: true)

            statRow(icon: "tray.and.arrow.down", color: AppColors.accent.opacity(0.7),
                    label: String(localized: "已下载", comment: "Downloaded"),
                    value: t.flatMap { formatBytes($0.dlInfoData) } ?? "—")

            statRow(icon: "tray.and.arrow.up", color: AppColors.success.opacity(0.7),
                    label: String(localized: "已上传", comment: "Uploaded"),
                    value: t.flatMap { formatBytes($0.upInfoData) } ?? "—")

            statRow(icon: "network", color: AppColors.accent.opacity(0.6),
                    label: "DHT",
                    value: s.flatMap { "\($0.dhtNodes) " + String(localized: "节点", comment: "nodes") } ?? "—")

            statRow(icon: "point.3.connected.trianglepath.dotted",
                    color: s.flatMap { connectionColor($0.connectionStatus) } ?? AppColors.tertiaryLabel,
                    label: String(localized: "连接状态", comment: "Connection status"),
                    value: s?.connectionStatus.capitalized ?? "—")
        } header: {
            Text(String(localized: "当前会话", comment: "Current session").uppercased())
        }
    }

    // MARK: - Server Info
    @ViewBuilder
    private var serverInfoSection: some View {
        if let s = transfer?.serverState {
            Section {
                statRow(icon: "internaldrive", color: Color(hex: "#8B5CF6"),
                        label: String(localized: "可用磁盘空间", comment: "Free disk space"),
                        value: formatBytes(s.freeSpaceOnDisk))

                statRow(icon: "hourglass", color: AppColors.warning,
                        label: String(localized: "队列状态", comment: "Queue status"),
                        value: s.queueing ? String(localized: "排队中", comment: "Queueing") : String(localized: "正常", comment: "Normal"))
            } header: {
                Text(String(localized: "服务器信息", comment: "Server info").uppercased())
            }
        }
    }

    // MARK: - Torrent Status
    private var torrentStatusSection: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count

        return Section {
            statRow(icon: "square.stack", color: AppColors.label,
                    label: String(localized: "种子总数", comment: "Total torrents"),
                    value: "\(torrents.count)")

            statRow(icon: "arrow.down.circle", color: AppColors.accent,
                    label: OrbixStrings.statsDownloading,
                    value: "\(dl)")

            statRow(icon: "arrow.up.circle", color: AppColors.success,
                    label: OrbixStrings.statsSeeding,
                    value: "\(up)")

            statRow(icon: "pause.circle", color: AppColors.tertiaryLabel,
                    label: OrbixStrings.statsPaused,
                    value: "\(paused)")

            statRow(icon: "exclamationmark.circle", color: AppColors.danger,
                    label: OrbixStrings.statsError,
                    value: "\(errored)")
        } header: {
            Text(String(localized: "种子状态", comment: "Torrent status").uppercased())
        }
    }

    // MARK: - Row Helper
    private func statRow(icon: String, color: Color, label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(color)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(monospaced ? .system(size: 15, weight: .regular, design: .monospaced) : .system(size: 15, weight: .regular))
                .foregroundColor(AppColors.label)
        }
    }

    // MARK: - Data
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
                let ver = try? await QBitApi.shared.getAppVersion()
                await MainActor.run {
                    transfer = t
                    torrents = list
                    serverVersion = ver ?? ""
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#if DEBUG
#Preview {
    StatsView()
}
#endif
