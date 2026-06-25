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
    @Namespace private var animationNamespace

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
                        Color.clear.frame(height: 10)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())

                        ForEach(filteredTorrents) { torrent in
                            ZStack {
                                NavigationLink(destination: TorrentDetailView(hash: torrent.hash)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                TorrentRow(torrent: torrent)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(AppColors.card)
                                    )
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    executeDelete(torrent)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                        
                        Color.clear.frame(height: 80)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await manualRefresh()
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTorrents.map(\.id))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if globalDlSpeed > 0 || globalUpSpeed > 0 {
                    GlobalSpeedPill(dl: globalDlSpeed, up: globalUpSpeed)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                } else {
                    Color.clear.frame(height: 0)
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TorrentFilter.allCases, id: \.self) { f in
                    Button {
                        let impact = UISelectionFeedbackGenerator()
                        impact.selectionChanged()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            filter = f
                        }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 14, weight: filter == f ? .bold : .medium))
                            .foregroundColor(filter == f ? .white : AppColors.secondaryLabel)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                ZStack {
                                    if filter == f {
                                        Capsule()
                                            .fill(AppColors.accent)
                                            .matchedGeometryEffect(id: "pillBg", in: animationNamespace)
                                    } else {
                                        Capsule()
                                            .fill(AppColors.card.opacity(0.6))
                                    }
                                }
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
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
            let list = (try? await QBitApi.shared.getTorrents()) ?? torrents
            let transfer = try? await QBitApi.shared.getTransferInfo()

            await MainActor.run {
                self.torrents = list
                self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
                self.isLoading = false
            }
        }
    }
    
    @Sendable private func manualRefresh() async {
        let list = (try? await QBitApi.shared.getTorrents()) ?? torrents
        let transfer = try? await QBitApi.shared.getTransferInfo()
        await MainActor.run {
            self.torrents = list
            self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
            self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
        }
    }

    private func executeDelete(_ torrent: TorrentInfo) {
        Task {
            do {
                try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: true)
                
                await MainActor.run {
                    withAnimation {
                        self.torrents.removeAll { $0.hash == torrent.hash }
                    }
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - 组件部分保持不变
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
                .frame(height: 3)
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
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.secondaryLabel
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
        case .downloading, .stalledDL, .forcedDL: return "arrow.down"
        case .uploading, .stalledUP, .forcedUP: return "arrow.up"
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP: return "pause.fill"
        case .queuedDL, .queuedUP: return "clock.fill"
        case .error, .missingFiles: return "exclamationmark.triangle.fill"
        case .checkingDL, .checkingUP, .checkingResumeData, .allocating: return "arrow.triangle.2.circlepath"
        case .metaDL: return "doc.text.magnifyingglass"
        case .moving: return "folder.fill"
        default: return "questionmark"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success.opacity(0.15)
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent.opacity(0.15)
        case .error, .missingFiles: return AppColors.danger.opacity(0.15)
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.tertiaryLabel.opacity(0.15)
        default: return AppColors.separator.opacity(0.3)
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }
}
