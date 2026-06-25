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
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack {
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
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                } else {
                    List {
                        ForEach(filteredTorrents) { torrent in
                            Section {
                                ZStack {
                                    NavigationLink(destination: TorrentDetailView(hash: torrent.hash)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    TorrentRow(torrent: torrent)
                                }
                                .listRowBackground(AppColors.card)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 10)
                }
            }
            .overlay(alignment: .bottom) {
                if globalDlSpeed > 0 || globalUpSpeed > 0 {
                    GlobalSpeedPill(dl: globalDlSpeed, up: globalUpSpeed)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: globalDlSpeed > 0 || globalUpSpeed > 0)
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
                                .font(.system(size: 15, weight: filter == f ? .semibold : .medium))
                                .foregroundColor(filter == f ? AppColors.label : AppColors.secondaryLabel)
                                .padding(.vertical, 8)

                            if filter == f {
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(AppColors.accent)
                                    .frame(width: 24, height: 3)
                                    .matchedGeometryEffect(id: "underline", in: animationNamespace)
                            } else {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.clear)
                                    .frame(width: 0, height: 3)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
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
                let transfer = try? await QBitApi.shared.getTransferInfo()

                await MainActor.run {
                    self.torrents = list
                    self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                    self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

private struct GlobalSpeedPill: View {
    let dl: Int64
    let up: Int64

    var body: some View {
        HStack(spacing: 16) {
            if dl > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .bold))
                    Text(formatSpeed(dl))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(AppColors.accent)
            }

            if up > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                    Text(formatSpeed(up))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(AppColors.success)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

private struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StatusIcon(status: torrent.statusBadge)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(torrent.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .lineLimit(2)
                        .padding(.trailing, 8)
                    
                    Spacer(minLength: 0)
                    
                    Text(formatBytes(torrent.size))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                
                HStack(spacing: 6) {
                    statusBadge
                    
                    Text("•")
                        .foregroundColor(AppColors.tertiaryLabel)
                        .font(.system(size: 10))
                    
                    Text("\(torrent.progressPercent)%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                    
                    if torrent.dlspeed > 0 {
                        Text("•")
                            .foregroundColor(AppColors.tertiaryLabel)
                            .font(.system(size: 10))
                        Text("↓\(formatSpeed(torrent.dlspeed))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.accent)
                    }
                    
                    if torrent.upspeed > 0 {
                        Text("•")
                            .foregroundColor(AppColors.tertiaryLabel)
                            .font(.system(size: 10))
                        Text("↑\(formatSpeed(torrent.upspeed))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.success)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.separator.opacity(0.5))
                        
                        Capsule()
                            .fill(progressColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
        }
    }

    private var statusBadge: some View {
        Text(torrent.statusBadge.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch torrent.statusBadge {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL: return AppColors.accent
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
                .frame(width: 36, height: 36)

            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch status {
        case .downloading: return "arrow.down"
        case .uploading: return "arrow.up"
        case .pausedDL, .pausedUP: return "pause.fill"
        case .error, .missingFiles: return "exclamationmark.triangle.fill"
        case .checkingDL, .checkingUP, .checkingResumeData, .allocating: return "arrow.triangle.2.circlepath"
        case .metaDL: return "doc.text.magnifyingglass"
        case .forcedUP: return "arrow.up"
        case .forcedDL: return "arrow.down"
        default: return "questionmark"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success.opacity(0.15)
        case .downloading, .metaDL, .forcedDL: return AppColors.accent.opacity(0.15)
        case .error, .missingFiles: return AppColors.danger.opacity(0.15)
        case .pausedDL, .pausedUP: return AppColors.tertiaryLabel.opacity(0.15)
        default: return AppColors.separator.opacity(0.3)
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }
}
