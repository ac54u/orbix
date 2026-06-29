import SwiftUI

struct TorrentListView: View {
    @State private var torrents: [TorrentInfo] = []
    @State private var filter: TorrentFilter = .all
    @State private var globalDlSpeed: Int64 = 0
    @State private var globalUpSpeed: Int64 = 0
    @State private var showAddTorrent = false
    @State private var isLoading = true
    @State private var showSpeedPanel = false
    @State private var gDlLimitStr = ""
    @State private var gUlLimitStr = ""
    @State private var altSpeedEnabled = false
    @State private var sortOrder: TorrentSort = .dateAdded
    @State private var selectedHash: String?
    @State private var isEditMode = false
    @State private var selectedHashes: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var processingAction: String?
    @Environment(\.scenePhase) private var scenePhase

    enum TorrentSort: CaseIterable {
        case dateAdded
        case name
        case progress
        case size
        case ratio
        case dlSpeed
        case upSpeed

        var displayName: String {
            switch self {
            case .dateAdded: return OrbixStrings.sortDateAdded
            case .name: return OrbixStrings.sortName
            case .progress: return OrbixStrings.sortProgress
            case .size: return OrbixStrings.sortSize
            case .ratio: return OrbixStrings.sortRatio
            case .dlSpeed: return OrbixStrings.sortDLSpeed
            case .upSpeed: return OrbixStrings.sortULSpeed
            }
        }

        var icon: String {
            switch self {
            case .dateAdded: return "calendar"
            case .name: return "textformat.abc"
            case .progress: return "chart.bar"
            case .size: return "internaldrive"
            case .ratio: return "chart.line.uptrend.xyaxis"
            case .dlSpeed: return "arrow.down"
            case .upSpeed: return "arrow.up"
            }
        }
    }

    enum TorrentFilter: CaseIterable {
        case all
        case downloading
        case seeding
        case active
        case paused
        case completed

        var displayName: String {
            switch self {
            case .all: return OrbixStrings.filterAll
            case .downloading: return OrbixStrings.statsDownloading
            case .seeding: return OrbixStrings.statsSeeding
            case .active: return OrbixStrings.filterActive
            case .paused: return OrbixStrings.statsPaused
            case .completed: return OrbixStrings.filterCompleted
            }
        }
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
                        Text(filter == .all ? OrbixStrings.msgNoTorrents : OrbixStrings.msgNoMatchingTorrents)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                } else {
                    List {
                        filterBar
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                        ForEach(filteredTorrents) { torrent in
                            HStack(spacing: 0) {
                                if isEditMode {
                                    selectionIcon(for: torrent)
                                        .padding(.trailing, AppSpacing.md)
                                }

                                TorrentRow(torrent: torrent)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    executeSingleAction(.deleteFiles, torrent)
                                } label: {
                                    Label(OrbixStrings.btnDelete, systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    executeSingleAction(torrent.statusBadge.isPaused ? .start : .stop, torrent)
                                } label: {
                                    Label(
                                        torrent.statusBadge.isPaused ? OrbixStrings.btnStart : OrbixStrings.btnPause,
                                        systemImage: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill"
                                    )
                                }
                                .tint(torrent.statusBadge.isPaused ? AppColors.success : AppColors.warning)
                            }
                            .contextMenu { contextMenuItems(for: torrent) }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isEditMode {
                                    toggleSelection(torrent.hash)
                                } else {
                                    selectedHash = torrent.hash
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.mainBg)
                    .refreshable {
                        await manualRefresh()
                    }
                    .navigationDestination(item: $selectedHash) { hash in
                        TorrentDetailView(hash: hash)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if isEditMode && !selectedHashes.isEmpty {
                        batchActionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !isEditMode && (globalDlSpeed > 0 || globalUpSpeed > 0) {
                        GlobalSpeedPill(dl: globalDlSpeed, up: globalUpSpeed)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .animation(AppMotion.standardCurve, value: globalDlSpeed > 0 || globalUpSpeed > 0)
            .animation(AppMotion.mediumAnim(), value: isEditMode)
            .animation(AppMotion.mediumAnim(), value: selectedHashes.count)
            .navigationTitle(OrbixStrings.tabTorrents)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if isEditMode {
                            selectedHashes.removeAll()
                            isEditMode = false
                        } else {
                            isEditMode = true
                        }
                    } label: {
                        Text(isEditMode ? OrbixStrings.btnDone : OrbixStrings.btnEdit)
                            .fontWeight(.medium)
                            .foregroundColor(isEditMode ? AppColors.accent : AppColors.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditMode {
                        Button { showSpeedPanel = true } label: {
                            Image(systemName: altSpeedEnabled ? "tortoise.fill" : "speedometer")
                                .foregroundColor(altSpeedEnabled ? AppColors.warning : AppColors.accent)
                        }
                        .accessibilityLabel(OrbixStrings.sectionGlobalSpeedLimit)
                    } else {
                        Button {
                            if selectedHashes.count == filteredTorrents.count {
                                selectedHashes.removeAll()
                            } else {
                                selectedHashes = Set(filteredTorrents.map(\.hash))
                            }
                        } label: {
                            Text(selectedHashes.count == filteredTorrents.count ? OrbixStrings.btnDeselectAll : OrbixStrings.btnSelectAll)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditMode {
                        Menu {
                            ForEach(TorrentSort.allCases, id: \.self) { sort in
                                Button {
                                    sortOrder = sort
                                } label: {
                                    HStack {
                                        Text(sort.displayName)
                                        if sortOrder == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel(OrbixStrings.sortName)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !isEditMode {
                        Button {
                            showAddTorrent = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(OrbixStrings.navAddTorrent)
                    }
                }
            }
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard scenePhase == .active else { return }
                refresh()
            }
            .sheet(isPresented: $showAddTorrent) {
                AddTorrentView()
            }
            .sheet(isPresented: $showSpeedPanel) {
                speedPanel
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert(OrbixStrings.miscDeleteTorrentTitle, isPresented: $showBatchDeleteAlert) {
                Button(OrbixStrings.btnDeleteTaskFiles, role: .destructive) { executeBatchDelete(deleteFiles: true) }
                Button(OrbixStrings.btnDeleteTaskOnly, role: .destructive) { executeBatchDelete(deleteFiles: false) }
                Button(OrbixStrings.btnCancel, role: .cancel) {}
            } message: {
                Text(String(format: OrbixStrings.infoBatchDeleteConfirm, selectedHashes.count))
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
                        
                        withAnimation(AppMotion.fastAnim()) {
                            filter = f
                        }
                    } label: {
                        Text(f.displayName)
                            .font(.system(size: 14, weight: filter == f ? .bold : .medium))
                            .foregroundColor(filter == f ? AppColors.label : AppColors.secondaryLabel)
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
                    .accessibilityLabel(f.displayName)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Selection
    private func selectionIcon(for torrent: TorrentInfo) -> some View {
        let isSelected = selectedHashes.contains(torrent.hash)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryLabel)
            .frame(width: 28)
    }

    private func toggleSelection(_ hash: String) {
        let impact = UISelectionFeedbackGenerator()
        impact.selectionChanged()
        if selectedHashes.contains(hash) {
            selectedHashes.remove(hash)
        } else {
            selectedHashes.insert(hash)
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuItems(for torrent: TorrentInfo) -> some View {
        if torrent.statusBadge.isPaused {
            Button {
                executeSingleAction(.start, torrent)
            } label: {
                Label(OrbixStrings.btnStart, systemImage: "play.fill")
            }
        } else if torrent.isActive {
            Button {
                executeSingleAction(.stop, torrent)
            } label: {
                Label(OrbixStrings.btnPause, systemImage: "pause.fill")
            }
        }

        if !torrent.statusBadge.isError {
            Button {
                executeSingleAction(.force, torrent)
            } label: {
                Label(OrbixStrings.btnForce, systemImage: "bolt.fill")
            }
        }

        Button {
            executeSingleAction(.recheck, torrent)
        } label: {
            Label(OrbixStrings.btnRecheck, systemImage: "checkmark.shield.fill")
        }

        Button {
            executeSingleAction(.announce, torrent)
        } label: {
            Label(OrbixStrings.btnAnnounce, systemImage: "antenna.radiowaves.left.and.right")
        }

        Divider()

        Button(role: .destructive) {
            executeSingleAction(.deleteTask, torrent)
        } label: {
            Label(OrbixStrings.btnDeleteTaskOnly, systemImage: "trash")
        }

        Button(role: .destructive) {
            executeSingleAction(.deleteFiles, torrent)
        } label: {
            Label(OrbixStrings.btnDeleteTaskFiles, systemImage: "trash.fill")
        }
    }

    // MARK: - Single Action
    private enum SingleActionType {
        case start, stop, force, recheck, announce, deleteTask, deleteFiles
    }

    private func executeSingleAction(_ type: SingleActionType, _ torrent: TorrentInfo) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        processingAction = torrent.hash

        Task {
            do {
                switch type {
                case .start:
                    try await QBitApi.shared.startTorrent(torrent.hash)
                case .stop:
                    try await QBitApi.shared.stopTorrent(torrent.hash)
                case .force:
                    try await QBitApi.shared.forceStartTorrent(torrent.hash)
                case .recheck:
                    try await QBitApi.shared.recheckTorrent(torrent.hash)
                case .announce:
                    try await QBitApi.shared.reannounceTorrent(torrent.hash)
                case .deleteTask:
                    try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: false)
                    await MainActor.run {
                        withAnimation(AppMotion.mediumAnim()) {
                            self.torrents.removeAll { $0.hash == torrent.hash }
                        }
                    }
                case .deleteFiles:
                    try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: true)
                    await MainActor.run {
                        withAnimation(AppMotion.mediumAnim()) {
                            self.torrents.removeAll { $0.hash == torrent.hash }
                        }
                    }
                }
                if type != .deleteTask && type != .deleteFiles {
                    await MainActor.run { processingAction = nil }
                    refresh()
                }
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } catch {
                await MainActor.run { processingAction = nil }
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Batch Actions
    private var batchActionBar: some View {
        HStack(spacing: 12) {
            Text(String(format: OrbixStrings.miscSelectedCount, selectedHashes.count))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.secondaryLabel)

            Spacer()

            Button {
                executeBatchAction(.stop)
            } label: {
                Label(OrbixStrings.btnBatchPause, systemImage: "pause.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .tint(AppColors.warning)

            Button {
                executeBatchAction(.start)
            } label: {
                Label(OrbixStrings.btnBatchResume, systemImage: "play.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .tint(AppColors.success)

            Button(role: .destructive) {
                showBatchDeleteAlert = true
            } label: {
                Label(OrbixStrings.btnBatchDelete, systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func executeBatchAction(_ type: SingleActionType) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        let hashes = selectedHashes.joined(separator: "|")

        Task {
            do {
                switch type {
                case .start:
                    try await QBitApi.shared.startTorrent(hashes)
                case .stop:
                    try await QBitApi.shared.stopTorrent(hashes)
                default:
                    break
                }
                await MainActor.run { selectedHashes.removeAll() }
                refresh()
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } catch {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
        }
    }

    private func executeBatchDelete(deleteFiles: Bool) {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        let hashes = selectedHashes.joined(separator: "|")

        Task {
            do {
                try await QBitApi.shared.deleteTorrent(hashes, deleteFiles: deleteFiles)
                await MainActor.run {
                    withAnimation(AppMotion.mediumAnim()) {
                        torrents.removeAll { selectedHashes.contains($0.hash) }
                        selectedHashes.removeAll()
                    }
                }
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } catch {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Filter & Sort

    private var filteredTorrents: [TorrentInfo] {
        let base = switch filter {
        case .all: torrents
        case .downloading: torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }
        case .seeding: torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }
        case .active: torrents.filter { $0.isActive }
        case .paused: torrents.filter { $0.statusBadge.isPaused }
        case .completed: torrents.filter { $0.isCompleted }
        }
        switch sortOrder {
        case .dateAdded: return base.sorted { $0.addedOn > $1.addedOn }
        case .name: return base.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .progress: return base.sorted { $0.progress > $1.progress }
        case .size: return base.sorted { $0.size > $1.size }
        case .ratio: return base.sorted { $0.ratio > $1.ratio }
        case .dlSpeed: return base.sorted { $0.dlspeed > $1.dlspeed }
        case .upSpeed: return base.sorted { $0.upspeed > $1.upspeed }
        }
    }

    private func refresh() {
        Task {
            let list = (try? await QBitApi.shared.getTorrents()) ?? torrents
            let transfer = try? await QBitApi.shared.getTransferInfo()
            let prefs = try? await QBitApi.shared.getPreferences()

            await MainActor.run {
                self.torrents = list
                self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
                if let p = prefs {
                    self.altSpeedEnabled = p["alt_speed_limit_enabled"] as? Bool ?? false
                    if gDlLimitStr.isEmpty, let dl = p["dl_limit"] as? Int64, dl > 0 {
                        gDlLimitStr = "\(dl / 1024)"
                    }
                    if gUlLimitStr.isEmpty, let ul = p["up_limit"] as? Int64, ul > 0 {
                        gUlLimitStr = "\(ul / 1024)"
                    }
                }
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

    // MARK: - Speed Control Panel
    private var speedPanel: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label(OrbixStrings.labelAltSpeedMode, systemImage: "tortoise")
                            .foregroundColor(AppColors.label)
                        Spacer()
                        Toggle("", isOn: $altSpeedEnabled)
                            .labelsHidden()
                            .tint(AppColors.warning)
                            .onChange(of: altSpeedEnabled) { _, _ in
                                Task {
                                    try? await QBitApi.shared.toggleSpeedLimitsMode()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                    }
                } header: {
                    Text(OrbixStrings.sectionMode)
                } footer: {
                    Text(OrbixStrings.infoAltSpeedHint)
                }

                SpeedLimitSection(
                    sectionTitle: OrbixStrings.sectionGlobalSpeedLimit,
                    footerText: OrbixStrings.infoEmptyZeroGlobalHint,
                    dlLimitStr: $gDlLimitStr,
                    ulLimitStr: $gUlLimitStr,
                    onApply: {
                        Task {
                            let dl = Int64(gDlLimitStr) ?? -1
                            let ul = Int64(gUlLimitStr) ?? -1
                            if dl >= 0 { try? await QBitApi.shared.setGlobalDownloadLimit(dl > 0 ? dl * 1024 : 0) }
                            if ul >= 0 { try? await QBitApi.shared.setGlobalUploadLimit(ul > 0 ? ul * 1024 : 0) }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                )
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle(OrbixStrings.navGlobalControl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(OrbixStrings.btnDone) { showSpeedPanel = false }
                        .fontWeight(.medium).foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    TorrentListView()
}
#endif

