import SwiftUI

struct TorrentListView: View {
    @State private var torrents: [TorrentInfo] = []
    @State private var filter: TorrentFilter = .all
    @State private var globalDlSpeed: Int64 = 0
    @State private var globalUpSpeed: Int64 = 0
    @State private var showAddTorrent = false
    @State private var isLoading = true

    enum TorrentFilter: String, CaseIterable {
        case all = "All"
        case downloading = "Downloading"
        case seeding = "Seeding"
        case active = "Active"
        case paused = "Paused"
        case completed = "Completed"
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
                    .insetGroupedStyle()
                }
            }
            .navigationTitle("Torrents")
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(TorrentFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.snappy) { filter = f }
                    } label: {
                        VStack(spacing: 6) {
                            Text(f.rawValue)
                                .subtitle(filter == f ? AppColors.label : AppColors.tertiaryLabel)
                                .fontWeight(filter == f ? .semibold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(filter == f ? AppColors.accent : .clear)
                                .frame(height: 2)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
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
            do {
                let list = try await QBitApi.shared.getTorrents()
                let transfer = try await QBitApi.shared.getTransferInfo()
                await MainActor.run {
                    torrents = list
                    globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                    globalUpSpeed = transfer?.upInfoSpeed ?? 0
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

private struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                StatusIcon(status: torrent.statusBadge)

                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.name)
                        .bodyFont()
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(torrent.statusBadge.displayName, systemImage: statusIconName)
                            .caption(statusColor)

                        SpeedBadge(speed: torrent.dlspeed)
                        Text("\(torrent.progressPercent)%")
                            .caption()
                        if torrent.eta > 0 {
                            Text(torrent.etaFormatted)
                                .caption()
                        }
                    }
                }

                Spacer()

                Text("\(torrent.progressPercent)%")
                    .cardTitle(AppColors.accent)
            }

            ProgressBar(progress: torrent.progress, color: progressColor)
        }
        .padding(.vertical, 4)
    }

    private var statusIconName: String {
        switch torrent.statusBadge {
        case .downloading: return "arrow.down.circle"
        case .uploading: return "arrow.up.circle"
        case .pausedDL, .pausedUP: return "pause.circle"
        case .error, .missingFiles: return "exclamationmark.circle"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch torrent.statusBadge {
        case .uploading, .stalledUP: return AppColors.success
        case .downloading, .metaDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP: return AppColors.tertiaryLabel
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
