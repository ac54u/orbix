import SwiftUI

struct TorrentDetailView: View {
    let hash: String

    @Environment(\.dismiss) private var dismiss
    @State private var torrent: TorrentInfo?
    @State private var properties: TorrentProperties?
    @State private var files: [TorrentFile] = []
    @State private var trackers: [TorrentTracker] = []
    @State private var peers: [TorrentPeer] = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true
    @State private var processingAction: ActionType? = nil
    @State private var lastAnnounceAt: Date? = nil
    @State private var loadError: String? = nil
    @State private var announceCooldown = false
    @State private var showAdvancedSheet = false
    @State private var newLocation = ""
    @State private var newName = ""
    @State private var dlLimitStr = ""
    @State private var ulLimitStr = ""
    @State private var showFileSheet = false
    @State private var showTrackerSheet = false
    @State private var newTrackerURL = ""
    @State private var selectedFileIndices: Set<Int> = []

    enum ActionType {
        case pause, force, recheck, announce
    }

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
            } else if let err = loadError {
                errorStateView(err)
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
                            timeSection(torrent, props: properties)
                        }

                        if !files.isEmpty {
                            filesSection
                        }

                        if !trackers.isEmpty {
                            trackersSection
                        }

                        if !peers.isEmpty {
                            peersSection
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let t = torrent {
                        newLocation = properties?.savePath ?? ""
                        newName = t.name
                        dlLimitStr = t.dlLimit > 0 ? "\(t.dlLimit / 1024)" : ""
                        ulLimitStr = t.upLimit > 0 ? "\(t.upLimit / 1024)" : ""
                    }
                    showAdvancedSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(AppColors.accent)
                }
            }
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
        .sheet(isPresented: $showAdvancedSheet) {
            advancedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFileSheet) {
            filePrioritySheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTrackerSheet) {
            trackerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task { await autoRefreshLoop() }
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
                icon: announceCooldown ? "clock.fill" : "antenna.radiowaves.left.and.right",
                label: announceCooldown ? "请稍候" : "汇报",
                color: announceCooldown ? AppColors.secondaryLabel : AppColors.accent,
                isLoading: processingAction == .announce || announceCooldown,
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
                DetailRow(icon: "person.2.fill", iconColor: AppColors.secondaryLabel, label: "种子/吸血", value: "\(String(torrent.numSeeds)) / \(String(torrent.numLeechs))")
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
            HStack {
                SectionHeader(title: "文件 (\(files.count))")
                Spacer()
                Button {
                    showFileSheet = true
                } label: {
                    Text("管理")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .padding(.trailing, 16)
            }
            VStack(spacing: 0) {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.label)
                            .lineLimit(2)

                        HStack {
                            Text(formatBytes(file.size))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Text("\(file.progressPercent)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(file.progress >= 1.0 ? AppColors.success : AppColors.accent)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1, style: .continuous)
                                    .fill(AppColors.separator.opacity(0.4))
                                RoundedRectangle(cornerRadius: 1, style: .continuous)
                                    .fill(file.progress >= 1.0 ? AppColors.success : AppColors.accent)
                                    .frame(width: max(0, geometry.size.width * CGFloat(file.progress)))
                            }
                        }
                        .frame(height: 3)
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

    // MARK: - Time Section
    private func timeSection(_ torrent: TorrentInfo, props: TorrentProperties?) -> some View {
        let added = props?.addedOn ?? torrent.addedOn
        let completed = props?.completionOn ?? torrent.completionOn
        return VStack(spacing: 0) {
            SectionHeader(title: "时间")
            VStack(spacing: 0) {
                DetailRow(icon: "calendar.badge.plus", iconColor: AppColors.secondaryLabel, label: "添加时间", value: formatUnixTime(added))
                if completed > 0 {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "checkmark.seal.fill", iconColor: AppColors.success, label: "完成时间", value: formatUnixTime(completed))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Trackers Section
    private var trackersSection: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader(title: "Trackers (\(trackers.count))")
                Spacer()
                Button {
                    showTrackerSheet = true
                } label: {
                    Text("管理")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .padding(.trailing, 16)
            }
            VStack(spacing: 0) {
                ForEach(trackers.indices, id: \.self) { index in
                    let tracker = trackers[index]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(trackerStatusColor(tracker.status))
                                .frame(width: 8, height: 8)
                            Text(tracker.statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(trackerStatusColor(tracker.status))
                            Spacer()
                        }
                        Text("种子：\(tracker.numSeeds) • 下载：\(tracker.numLeeches)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Text(tracker.url)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < trackers.count - 1 {
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

    // MARK: - Peers Section
    private var peersSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Peers (\(peers.count))")
            VStack(spacing: 0) {
                ForEach(peers.indices, id: \.self) { index in
                    let peer = peers[index]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(peer.ip):\(String(peer.port))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.label)
                            if !peer.country.isEmpty {
                                Text(peer.country)
                                    .font(.system(size: 12))
                                    .foregroundColor(countryColor(peer.countryCode))
                            }
                            Spacer()
                            if peer.upSpeed > 0 {
                                Text("↑ \(formatSpeed(peer.upSpeed))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(AppColors.success)
                            }
                            Text("\(peer.progressPercent)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                        if !peer.client.isEmpty {
                            Text(peer.client)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.tertiaryLabel.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < peers.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                            .opacity(0.4)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private func countryColor(_ code: String) -> Color {
        switch code.uppercased() {
        case "CN", "HK", "TW", "MO": return AppColors.danger
        case "JP": return AppColors.accent
        case "US", "GB", "CA", "AU": return AppColors.success
        case "KR": return AppColors.warning
        default: return AppColors.secondaryLabel
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.danger.opacity(0.1))
        )
    }

    @ViewBuilder
    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.danger)

            Text("加载失败")
                .font(.headline)
                .foregroundColor(AppColors.label)

            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)

            Button("重试") {
                loadError = nil
                isLoading = true
                Task { await refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
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

    private func refresh() async {
        do {
            async let t = QBitApi.shared.getTorrentByHash(hash)
            async let p = QBitApi.shared.getProperties(hash)
            async let f = QBitApi.shared.getTorrentFiles(hash)
            async let tr = QBitApi.shared.getTorrentTrackers(hash)
            async let pe = QBitApi.shared.getTorrentPeers(hash)
            let (torrent, properties, files, trackers, peers) = try await (t, p, f, tr, pe)
            try Task.checkCancellation()
            await MainActor.run {
                self.torrent = torrent
                self.properties = properties
                self.files = files
                self.trackers = trackers
                self.peers = peers
                isLoading = false
                loadError = nil
            }
        } catch is CancellationError {
            // Task cancelled, exit silently
        } catch {
            await MainActor.run {
                isLoading = false
                if torrent == nil {
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func autoRefreshLoop() async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }

    @Sendable private func manualRefresh() async {
        let t = try? await QBitApi.shared.getTorrentByHash(hash)
        let p = try? await QBitApi.shared.getProperties(hash)
        let f = (try? await QBitApi.shared.getTorrentFiles(hash)) ?? []
        let tr = (try? await QBitApi.shared.getTorrentTrackers(hash)) ?? []
        let pe = (try? await QBitApi.shared.getTorrentPeers(hash)) ?? []
        await MainActor.run {
            if let t = t { self.torrent = t }
            if let p = p { self.properties = p }
            self.files = f
            self.trackers = tr
            self.peers = pe
            if t != nil { loadError = nil }
        }
    }

    private func performAction(_ type: ActionType, torrent: TorrentInfo) {
        guard processingAction == nil else { return }

        if type == .announce, announceCooldown { return }

        processingAction = type
        let oldState = torrent.state
        let oldDlspeed = torrent.dlspeed
        let oldUpspeed = torrent.upspeed
        let oldProgress = torrent.progress

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
                    lastAnnounceAt = Date()
                    announceCooldown = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        announceCooldown = false
                    }
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Smart polling with exponential backoff + state diffing
                var interval: UInt64 = 300_000_000
                let maxInterval: UInt64 = 1_200_000_000
                var attempt = 0

                while attempt < 6 {
                    do {
                        try await Task.sleep(nanoseconds: interval)
                    } catch {
                        break
                    }
                    attempt += 1

                    if let newTorrent = try? await QBitApi.shared.getTorrentByHash(hash) {
                        let stateChanged = newTorrent.state != oldState
                        let speedChanged = abs(newTorrent.dlspeed - oldDlspeed) > 1024
                            || abs(newTorrent.upspeed - oldUpspeed) > 1024
                        let progressChanged = abs(newTorrent.progress - oldProgress) > 0.001

                        if stateChanged || speedChanged || progressChanged || attempt >= 6 {
                            await MainActor.run { self.torrent = newTorrent }
                            break
                        }
                    }

                    interval = min(maxInterval, interval * 13 / 8)
                }

                // Final sync for properties, files, trackers, peers
                let p = try? await QBitApi.shared.getProperties(hash)
                let f = try? await QBitApi.shared.getTorrentFiles(hash)
                let tr = try? await QBitApi.shared.getTorrentTrackers(hash)
                let pe = try? await QBitApi.shared.getTorrentPeers(hash)
                await MainActor.run {
                    if let p = p { properties = p }
                    if let f = f { files = f }
                    if let tr = tr { trackers = tr }
                    if let pe = pe { peers = pe }
                }

            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }

            await MainActor.run {
                processingAction = nil
            }
        }
    }

    // MARK: - Advanced Controls Sheet
    private var advancedSheet: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("修改保存路径")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                        TextField("输入新的保存路径", text: $newLocation)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppColors.label)
                    }
                    .padding(.vertical, 4)

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            try? await QBitApi.shared.setTorrentLocation(hash, location: newLocation)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Text("应用路径")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newLocation.isEmpty ? AppColors.elevated : AppColors.accent)
                            )
                            .foregroundColor(newLocation.isEmpty ? AppColors.secondaryLabel : .white)
                    }
                    .disabled(newLocation.isEmpty)
                } header: {
                    Text("位置")
                }

                Section {
                    TextField("重命名", text: $newName)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.label)

                    Button {
                        Task {
                            try? await QBitApi.shared.renameTorrent(hash, name: newName)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showAdvancedSheet = false
                        }
                    } label: {
                        Text("应用名称")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newName.isEmpty ? AppColors.elevated : AppColors.accent)
                            )
                            .foregroundColor(newName.isEmpty ? AppColors.secondaryLabel : .white)
                    }
                    .disabled(newName.isEmpty)
                } header: {
                    Text("重命名")
                }

                Section {
                    HStack {
                        Text("下载限速")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("不限速", text: $dlLimitStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                        Text("KB/s")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }

                    HStack {
                        Text("上传限速")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("不限速", text: $ulLimitStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                        Text("KB/s")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            let dl = (Int64(dlLimitStr) ?? -1)
                            let ul = (Int64(ulLimitStr) ?? -1)
                            if dl > 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: dl * 1024) }
                            else if dl == 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: 0) }
                            if ul > 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: ul * 1024) }
                            else if ul == 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: 0) }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Text("应用限速")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.accent)
                            )
                            .foregroundColor(.white)
                    }
                } header: {
                    Text("速度限制")
                } footer: {
                    Text("留空或填 0 表示不限速")
                }

                Section {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            try? await QBitApi.shared.toggleSequentialDownload(hash)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        HStack {
                            Label("切换顺序下载", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                } header: {
                    Text("下载模式")
                } footer: {
                    Text("按文件顺序下载，适合预览媒体文件")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("高级控制")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showAdvancedSheet = false }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func delete(_ deleteFiles: Bool) {
        Task {
            try? await QBitApi.shared.deleteTorrent(hash, deleteFiles: deleteFiles)
            dismiss()
        }
    }

    // MARK: - File Priority Sheet
    private var filePrioritySheet: some View {
        NavigationStack {
            List {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    HStack(spacing: 10) {
                        Image(systemName: selectedFileIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFileIndices.contains(index) ? AppColors.accent : AppColors.tertiaryLabel)
                            .onTapGesture {
                                if selectedFileIndices.contains(index) {
                                    selectedFileIndices.remove(index)
                                } else {
                                    selectedFileIndices.insert(index)
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)
                            Text(formatBytes(file.size))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.secondaryLabel)
                        }

                        Spacer()

                        priorityBadge(file.priority)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("文件优先级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showFileSheet = false; selectedFileIndices = [] }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedFileIndices.isEmpty {
                        Menu {
                            Button { setPrio(0) } label: { Label("忽略", systemImage: "nosign") }
                            Button { setPrio(1) } label: { Label("正常", systemImage: "minus") }
                            Button { setPrio(6) } label: { Label("高", systemImage: "arrow.up") }
                            Button { setPrio(7) } label: { Label("最高", systemImage: "arrow.up.to.line") }
                        } label: {
                            Text("批量 (\(selectedFileIndices.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    Button("完成") { showFileSheet = false; selectedFileIndices = [] }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func priorityBadge(_ priority: Int) -> some View {
        let (label, color): (String, Color) = {
            switch priority {
            case 0: return ("忽略", AppColors.secondaryLabel)
            case 6: return ("高", AppColors.accent)
            case 7: return ("最高", AppColors.success)
            default: return ("正常", AppColors.tertiaryLabel)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.12))
            )
    }

    private func setPrio(_ priority: Int) {
        let indices = Array(selectedFileIndices)
        Task {
            try? await QBitApi.shared.setFilePriorities(hash, indices: indices, priority: priority)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Refresh files
            if let f = try? await QBitApi.shared.getTorrentFiles(hash) {
                await MainActor.run { files = f }
            }
        }
    }

    // MARK: - Tracker Management Sheet
    private var trackerSheet: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        TextField("输入 Tracker URL ...", text: $newTrackerURL)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppColors.label)
                        Button {
                            guard !newTrackerURL.isEmpty else { return }
                            let urls = newTrackerURL.components(separatedBy: "\n").filter { !$0.isEmpty }
                            Task {
                                try? await QBitApi.shared.addTrackers(hash, urls: urls)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                await MainActor.run { newTrackerURL = "" }
                                if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                    await MainActor.run { trackers = t }
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(newTrackerURL.isEmpty ? AppColors.tertiaryLabel : AppColors.accent)
                        }
                        .disabled(newTrackerURL.isEmpty)
                    }
                } header: {
                    Text("添加 Tracker")
                }

                Section {
                    ForEach(trackers) { tracker in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(trackerStatusColor(tracker.status))
                                    .frame(width: 8, height: 8)
                                Text(tracker.statusText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(trackerStatusColor(tracker.status))
                                Spacer()
                                Text("种子 \(tracker.numSeeds)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                            Text(tracker.url)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.secondaryLabel)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    try? await QBitApi.shared.removeTrackers(hash, urls: [tracker.url])
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                        await MainActor.run { trackers = t }
                                    }
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("当前 Trackers (\(trackers.count))")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("Tracker 管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showTrackerSheet = false }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func trackerStatusColor(_ status: Int) -> Color {
        switch status {
        case 0, 1: return AppColors.danger
        case 2, 4: return AppColors.success
        case 3: return AppColors.warning
        default: return AppColors.secondaryLabel
        }
    }

    private func formatUnixTime(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 HH:mm"
        return fmt.string(from: date)
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


