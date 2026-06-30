import SwiftUI

// MARK: - 搜索数据源
enum SearchSource: String, CaseIterable {
    case qBittorrent = "qB"
    case prowlarr = "Prowlarr"
    case radarr = "Radarr"

    var label: String {
        switch self {
        case .qBittorrent: return OrbixStrings.miscBuiltInSearch
        case .prowlarr: return "Prowlarr"
        case .radarr: return "Radarr"
        }
    }

    var icon: String {
        switch self {
        case .qBittorrent: return "arrow.down.circle"
        case .prowlarr: return "antenna.radiowaves.left.and.right"
        case .radarr: return "film"
        }
    }
}

struct QBitSearchView: View {
    @State private var query = ""
    @State private var plugins: [SearchPlugin] = []
    @State private var results: [SearchResult] = []
    @State private var selectedPlugins: Set<String> = ["all"]
    @State private var searchId: Int?
    @State private var status: String?
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    @State private var categories: [String] = []
    @State private var showDownloadSheet = false
    @State private var searchSource: SearchSource = .qBittorrent
    @State private var searchError: String?
    @ObservedObject private var searchMode = SearchModeState.shared

    @State private var selectedResult: SearchResult?
    @State private var showRadarrSheet = false
    @State private var radarrResult: SearchResult?
    @State private var qualityProfiles: [RadarrApi.QualityProfile] = []
    @State private var rootFolders: [RadarrApi.RootFolder] = []

    @ObservedObject private var creds = CredentialsManager.shared

    private var availableSources: [SearchSource] {
        var sources: [SearchSource] = []
        if creds.qBittorrent != nil { sources.append(.qBittorrent) }
        if creds.prowlarr != nil { sources.append(.prowlarr) }
        if creds.radarr != nil { sources.append(.radarr) }
        return sources.isEmpty ? [.qBittorrent] : sources
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    if availableSources.count > 1 {
                        sourceBar
                            .padding(.vertical, 8)
                    }
                    if searchSource == .qBittorrent {
                        pluginBar
                            .padding(.vertical, 8)
                    }

                    if isLoading && results.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(AppColors.accent)
                            Text(OrbixStrings.msgSearchingAll)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                        }
                    } else if let error = searchError {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppColors.warning)
                        Text(error)
                            .subtitle()
                            .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else if !query.isEmpty && results.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppColors.tertiaryLabel)
                        Text(OrbixStrings.errNoResults)
                            .subtitle()
                            if searchSource == .prowlarr {
                                Text(OrbixStrings.infoProwlarrHint)
                                    .caption()
                            }
                            Spacer()
                        }
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle(OrbixStrings.navExplore)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        searchMode.use141.toggle()
                    } label: {
                        Image(systemName: "globe")
                            .foregroundColor(AppColors.accent)
                            .font(.system(size: 14))
                    }
                }
            }
            .searchable(text: $query, placement: .automatic, prompt: OrbixStrings.phSearchKeyword)
            .onChange(of: query) { _, _ in debounceSearch() }
            .onAppear {
                loadPlugins()
                loadCategories()
            }
            .onDisappear {
                searchTask?.cancel()
                if let sid = searchId {
                    Task { try? await QBitApi.shared.stopSearch(id: sid) }
                }
            }
            .sheet(isPresented: $showDownloadSheet) {
                if let result = selectedResult {
                    QBitDownloadSheet(result: result, categories: categories, isFromProwlarr: searchSource == .prowlarr)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showRadarrSheet) {
                if let item = radarrResult {
                    QBitRadarrAddSheet(
                        item: item,
                        qualityProfiles: qualityProfiles,
                        rootFolders: rootFolders
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - 数据源选择
    private var sourceBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableSources, id: \.self) { source in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        searchSource = source
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: source.icon)
                                .font(.system(size: 12))
                            Text(source.label)
                                .font(.system(size: 13, weight: searchSource == source ? .semibold : .medium))
                        }
                        .foregroundColor(searchSource == source ? AppColors.label : AppColors.secondaryLabel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(searchSource == source ? AppColors.accent : AppColors.elevated)
                        )
                    }
                    .accessibilityLabel(source.label)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 极简插件栏
    private var pluginBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pluginChip("all", label: OrbixStrings.filterAll)
                ForEach(plugins) { plugin in
                    if plugin.enabled {
                        pluginChip(plugin.id, label: plugin.name)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func pluginChip(_ id: String, label: String) -> some View {
        let selected = selectedPlugins.contains(id)
        return Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            if id == "all" {
                selectedPlugins = ["all"]
            } else {
                selectedPlugins.remove("all")
                if selected { selectedPlugins.remove(id) } else { selectedPlugins.insert(id) }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundColor(selected ? AppColors.label : AppColors.label)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? AppColors.accent : Color.clear)
                        .background(
                            Capsule().fill(.regularMaterial)
                        )
                        .shadow(color: selected ? AppColors.accent.opacity(0.3) : .clear, radius: 4, y: 2)
                )
        }
    }

    // MARK: - 结果列表
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !results.isEmpty {
                    HStack {
                        Text(String(format: OrbixStrings.miscCountResults, results.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.secondaryLabel)
                            .textCase(.uppercase)
                        Spacer()
                        if status == "Running" {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                ForEach(results) { item in
                    QBitResultCard(
                        item: item,
                        searchSource: searchSource,
                        selectedResult: $selectedResult,
                        radarrResult: $radarrResult,
                        qualityProfiles: $qualityProfiles,
                        rootFolders: $rootFolders,
                        showRadarrSheet: $showRadarrSheet,
                        showDownloadSheet: $showDownloadSheet
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 数据加载
    private func loadPlugins() {
        Task {
            if let list = try? await QBitApi.shared.getSearchPlugins() {
                await MainActor.run { plugins = list }
            }
        }
    }

    private func loadCategories() {
        Task {
            if let cats = try? await QBitApi.shared.getCategories() {
                await MainActor.run { categories = cats }
            }
        }
    }

    // MARK: - 搜索逻辑
    private func debounceSearch() {
        if let sid = searchId {
            let oldId = sid
            searchId = nil
            Task { try? await QBitApi.shared.stopSearch(id: oldId) }
        }
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            searchError = nil
            isLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        await MainActor.run { isLoading = true; results = []; searchError = nil }
        switch searchSource {
        case .qBittorrent:
            await runQBitSearch()
        case .prowlarr:
            await runProwlarrSearch()
        case .radarr:
            await runRadarrSearch()
        }
    }

    private func runQBitSearch() async {
        do {
            let pList = selectedPlugins.contains("all")
                ? ["all"]
                : Array(selectedPlugins)
            guard let id = try await QBitApi.shared.startSearch(pattern: query, plugins: pList) else {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run { searchId = id }

            var attempts = 0
            while attempts < 30 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                attempts += 1

                if let items = try? await QBitApi.shared.getSearchResults(id: id) {
                    await MainActor.run {
                        self.results = items.sorted { $0.nbSeeders > $1.nbSeeders }
                    }
                }

                if let s = try? await QBitApi.shared.getSearchStatus(id: id) {
                    let st = s["status"] as? String ?? ""
                    await MainActor.run { status = st }
                    if st == "Stopped" { break }
                }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                isLoading = false
                searchError = OrbixStrings.errBuiltInSearchFailed + ": " + error.localizedDescription
            }
        }
    }

    private func runProwlarrSearch() async {
        do {
            let items: [SearchResult]
            if creds.radarr != nil {
                let movies = (try? await RadarrApi.lookup(query: query)) ?? []
                if let first = movies.first, first.num > 0 {
                    items = try await ProwlarrApi.searchMovie(tmdbId: first.num)
                } else {
                    items = try await ProwlarrApi.search(query: query)
                }
            } else {
                items = try await ProwlarrApi.search(query: query)
            }
            await MainActor.run {
                self.results = items.sorted { $0.nbSeeders > $1.nbSeeders }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                searchError = OrbixStrings.errProwlarrFailed + ": " + error.localizedDescription
            }
        }
    }

    private func runRadarrSearch() async {
        do {
            let items = try await RadarrApi.lookup(query: query)
            await MainActor.run {
                self.results = items
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                searchError = OrbixStrings.errRadarrFailed + ": " + error.localizedDescription
            }
        }
    }
}

#if DEBUG
#Preview {
    QBitSearchView()
}
#endif
