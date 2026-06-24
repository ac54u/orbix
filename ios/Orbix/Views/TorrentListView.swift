import SwiftUI

struct TorrentListView: View {
    @State private var torrents: [TorrentInfo] = []
    @State private var filter: TorrentFilter = .all
    @State private var globalDlSpeed: Int64 = 0
    @State private var globalUpSpeed: Int64 = 0
    @State private var showAddTorrent = false
    @State private var isLoading = true

    enum TorrentFilter: String, CaseIterable {
        case all = "全部"
        case downloading = "下载中"
        case seeding = "做种中"
        case active = "活动中"
        case paused = "已暂停"
        case completed = "已完成"
    }

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()

                if isLoading {
                    VStack {
                        SkeletonBar(height: 16)
                        SkeletonBar(height: 16)
                        SkeletonBar(height: 16)
                        SkeletonBar(height: 16)
                    }
                    .padding(.horizontal, 20)
                } else if filteredTorrents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)
                        Text(filter == .all ? "暂无种子" : "没有匹配的种子")
                            .subtitle()
                    }
                } else {
                    List {
                        if globalDlSpeed > 0 || globalUpSpeed > 0 {
                            Section {
                                HStack {
                                    SpeedBadge(speed: globalDlSpeed)
                                        .foregroundColor(AppColors.accent)
                                    Text("↓")
                                        .caption(AppColors.tertiaryLabel)
                                    SpeedBadge(speed: globalUpSpeed)
                                        .foregroundColor(AppColors.success)
                                    Text("↑")
                                        .caption(AppColors.tertiaryLabel)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(AppColors.card)
                            }
                        }

                        Section {
                            ForEach(filteredTorrents) { torrent in
                                NavigationLink(destination: TorrentDetailView(hash: torrent.hash)) {
                                    TorrentRow(torrent: torrent)
                                }
                                .listRowBackground(AppColors.card)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("种子")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTorrent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { refresh() }
            .onReceive(timer) { _ in refresh() }
            .sheet(isPresented: $showAddTorrent) {
                AddTorrentView()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterBar
            }
        }
    }

    @Namespace private var animationNamespace

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(TorrentFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(AppMotion.fastAnim()) {
                            filter = f
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(f.rawValue)
                                .subtitle(filter == f ? AppColors.label : AppColors.secondaryLabel)
                                .fontWeight(filter == f ? .semibold : .regular)
                                .padding(.vertical, 8)

                            if filter == f {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(AppColors.accent)
                                    .frame(width: 24, height: 1.5)
                                    .matchedGeometryEffect(id: "underline", in: animationNamespace)
                            } else {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.clear)
                                    .frame(width: 0, height: 1.5)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 36)
        .background(AppColors.groupedBg)
    }

    private var filteredTorrents: [TorrentInfo] {
        switch filter {
        case .all: return torrents
        case .downloading: return torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }
        case .seeding: return torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }
        case .active: return torrents.filter { $0.isActive }
        case .paused: return torrents.filter { $0.statusBadge.isPaused }
        case .completed: return torrents.filter { $0.isCompleted }
        }
    }

    private func refresh() {
        Task {
            let list = (try? await QBitApi.shared.getTorrents()) ?? []
            let transfer = (try? await QBitApi.shared.getTransferInfo())
            await MainActor.run {
                torrents = list
                globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                globalUpSpeed = transfer?.upInfoSpeed ?? 0
                isLoading = false
            }
        }
    }
}

private struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                StatusIcon(status: torrent.statusBadge)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 12) {
                        Text(torrent.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(AppColors.label)

                        Spacer()

                        Text(formatBytes(torrent.size))
                            .caption(AppColors.tertiaryLabel)
                    }

                    HStack(spacing: 0) {
                        statusBadge

                        if torrent.dlspeed > 0 {
                            Text("  ·  ")
                                .caption(AppColors.tertiaryLabel)
                            Text("↓ \(formatSpeed(torrent.dlspeed))")
                                .caption()
                        }

                        if torrent.upspeed > 0 {
                            Text("  ·  ")
                                .caption(AppColors.tertiaryLabel)
                            Text("↑ \(formatSpeed(torrent.upspeed))")
                                .caption()
                        }

                        Text("  ·  ")
                            .caption(AppColors.tertiaryLabel)
                        Text("\(torrent.progressPercent)%")
                            .caption()

                        if torrent.eta > 0 && torrent.eta < 8640000 {
                            Text("  ·  ")
                                .caption(AppColors.tertiaryLabel)
                            Text(torrent.etaFormatted)
                                .caption()
                        }

                        Spacer()
                    }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)

            ProgressBar(progress: torrent.progress, height: 1/UIScreen.main.scale, color: progressColor)
        }
    }

    private var statusBadge: some View {
        Text(torrent.statusBadge.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch torrent.statusBadge {
        case .uploading, .stalledUP: return AppColors.success
        case .downloading, .metaDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }

    private var progressColor: Color {
        if torrent.statusBadge.isError { return AppColors.danger }
        if torrent.isCompleted { return AppColors.success }
        return AppColors.accent
    }
}

private struct StatusIcon: View {
    let status: TorrentStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var iconName: String {
        switch status {
        case .downloading: return "arrow.down"
        case .uploading: return "arrow.up"
        case .pausedDL, .pausedUP: return "pause"
        case .error, .missingFiles: return "exclamationmark"
        case .checkingDL, .checkingUP, .checkingResumeData: return "arrow.triangle.2.circlepath"
        case .metaDL: return "doc.text.magnifyingglass"
        default: return "circle"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .uploading, .stalledUP: return AppColors.success.opacity(0.2)
        case .downloading, .metaDL: return AppColors.accent.opacity(0.2)
        case .error, .missingFiles: return AppColors.danger.opacity(0.2)
        case .pausedDL, .pausedUP: return AppColors.tertiaryLabel.opacity(0.2)
        default: return AppColors.separator
        }
    }
}
