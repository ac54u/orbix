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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTorrents) { torrent in
                                SwipeableTorrentCard(torrent: torrent) {
                                    executeDelete(torrent)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        Color.clear.frame(height: 80)
                    }
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
            .navigationBarTitleDisplayMode(.inline)
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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

// MARK: - 修复后的高级滑动卡片
private struct SwipeableTorrentCard: View {
    let torrent: TorrentInfo
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var navigateToDetail = false
    @State private var isDragging = false
    @State private var autoDismissTask: Task<Void, Never>?
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 隐藏的原生导航链接，不参与手势争夺
            NavigationLink(destination: TorrentDetailView(hash: torrent.hash), isActive: $navigateToDetail) {
                EmptyView()
            }
            .hidden()
            
            // 只有滑动时才渲染红底，杜绝点击透红
            if offset < 0 {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.danger)
                    .frame(width: 72)
                    .padding(.vertical, 4)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 16)
                            .scaleEffect(offset < -50 ? 1.2 : 0.9)
                            .opacity(offset < -20 ? 1 : 0)
                            .animation(.easeOut(duration: 0.2), value: offset)
                    }
                    .onTapGesture {
                        autoDismissTask?.cancel()
                        guard !isDeleting else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = -UIScreen.main.bounds.width
                            isDeleting = true
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDelete()
                            }
                        }
                    }
            }
            
            // 改用 Button，完全掌控点击与滑动
            Button {
                autoDismissTask?.cancel()
                guard !isDragging else { return }
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                } else {
                    navigateToDetail = true
                }
            } label: {
                TorrentRow(torrent: torrent)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.card)
                    )
            }
            .buttonStyle(SolidCardButtonStyle())
            .offset(x: offset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isDeleting else { return }
                    isDragging = true
                    if value.translation.width < 0 && abs(value.translation.width) > abs(value.translation.height) {
                        offset = value.translation.width * 0.8
                    }
                }
                .onEnded { value in
                    guard !isDeleting else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        offset = 0
                        isDragging = false
                        return
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if value.translation.width < -50 {
                            offset = -72
                        } else {
                            offset = 0
                        }
                    }
                    DispatchQueue.main.async {
                        isDragging = false
                    }
                }
        )
        .onChange(of: offset) { _, newValue in
            autoDismissTask?.cancel()
            guard newValue < 0, !isDeleting else { return }
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, !isDeleting else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
        }
    }
}

// MARK: - 无透明度衰减的高级按钮样式
struct SolidCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 其余 UI 组件
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

                    if torrent.ratio > 0 {
                        Text("•")
                            .foregroundColor(AppColors.tertiaryLabel)
                            .font(.system(size: 10))
                        Text(String(format: "%.2f", torrent.ratio))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(torrent.ratio >= 1.0 ? AppColors.success : AppColors.warning)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(AppColors.separator.opacity(0.5))
                        
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(progressColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                    }
                }
                .frame(height: 2.5)
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
