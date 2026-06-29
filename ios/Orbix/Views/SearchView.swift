import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [ScrapedTorrent] = []
    @State private var allResults: [ScrapedTorrent] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var state: SearchState = .idle
    @State private var bookmarks: Set<String> = []
    @State private var selectedTorrent: ScrapedTorrent?
    @State private var showMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var showingBookmarks = false

    enum SearchState { case idle, loading, results, empty, error(String) }
    enum ViewMode: String { case grid, list }

    @State private var searchTask: Task<Void, Never>?

    // MARK: - Grid Layout (pinch to zoom)
    @AppStorage("searchGridColumns") private var gridColumnCount = 4
    @State private var pinchBaseColumns: Int?
    @AppStorage("searchViewMode") private var viewModeRaw = ViewMode.grid.rawValue
    private var viewMode: ViewMode { ViewMode(rawValue: viewModeRaw) ?? .grid }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: gridColumnCount)
    }

    private var pinchToZoom: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let base = pinchBaseColumns ?? gridColumnCount
                if pinchBaseColumns == nil { pinchBaseColumns = gridColumnCount }
                // 往外撑(scale>1) → 列变少卡片变大；往里捏 → 列变多
                let steps = Int((scale - 1) * 3)
                let target = min(6, max(2, base - steps))
                if target != gridColumnCount {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        gridColumnCount = target
                    }
                }
            }
            .onEnded { _ in pinchBaseColumns = nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()
                switch state {
                case .idle: idleView
                case .loading: loadingView
                case .results: resultsView
                case .empty: emptyHint(OrbixStrings.errNoSearchResults, icon: "magnifyingglass")
                case .error(let m): emptyHint(m, icon: "exclamationmark.triangle", isError: true)
                }
            }
            .navigationTitle(OrbixStrings.navSearch)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            SearchModeState.shared.use141 = false
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(AppColors.accent)
                                .font(.system(size: 14))
                        }
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(AppMotion.mediumAnim()) {
                                viewModeRaw = (viewMode == .grid ? ViewMode.list : ViewMode.grid).rawValue
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.3x3")
                                .foregroundColor(AppColors.accent)
                                .font(.system(size: 15))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.none) { showingBookmarks.toggle() }
                } label: {
                    Image(systemName: showingBookmarks ? "heart.fill" : (bookmarks.isEmpty ? "heart" : "heart.fill"))
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel(OrbixStrings.navSearch)
                .id("bookmark_\(bookmarks.hashValue)_\(showingBookmarks)")
            }
        }
            .onAppear { loadBookmarks(); if allResults.isEmpty { loadLatest() } }
            .sheet(item: $selectedTorrent) { TorrentDetailSheet(torrent: $0, bookmarks: $bookmarks, onChanged: saveBookmarks) }
            .fullScreenCover(isPresented: $showMediaViewer) {
                let imgs = results.map { $0.thumbnail ?? "" }.filter { !$0.isEmpty }
                if !imgs.isEmpty {
                    MediaViewer(images: imgs, initialIndex: mediaViewerIndex)
                }
            }
        }
    }

    // MARK: - Idle / Trending
    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(AppColors.warning)
                    Text(OrbixStrings.msgBrowseHot).sectionHeader()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text(OrbixStrings.msgSearchSuggestion)
                    .subtitle(AppColors.tertiaryLabel)
                    .padding(.horizontal, 20)

                if results.isEmpty {
                    gridSkeleton
                } else if viewMode == .grid {
                    LazyVGrid(columns: gridColumns, spacing: 1) {
                        ForEach(results) { torrent in
                            TorrentCard(torrent: torrent)
                                .onTapGesture { selectedTorrent = torrent }
                                .contextMenu { cardContextMenu(torrent) }
                        }
                    }
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(results) { torrent in
                            ScrapedTorrentRow(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                                .contentShape(Rectangle())
                                .onTapGesture { selectedTorrent = torrent }
                                .contextMenu { cardContextMenu(torrent) }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
        .refreshable { await refreshSearch() }
        .gesture(viewMode == .grid ? pinchToZoom : nil)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().tint(AppColors.accent)
                Text(OrbixStrings.msgFetchingLatest).subtitle(AppColors.tertiaryLabel)
            }
            .padding(.top, 16)
            gridSkeleton
        }
    }

    // MARK: - Results
    private var displayResults: [ScrapedTorrent] {
        showingBookmarks ? results.filter { bookmarks.contains($0.code) } : results
    }

    private var sections: [(date: String, items: [ScrapedTorrent])] {
        let grouped = Dictionary(grouping: displayResults, by: { $0.date })
        return grouped.keys.sorted(by: >).compactMap { date in
            grouped[date].map { (date, $0) }
        }
    }

    private var resultsView: some View {
        ScrollView {
            if showingBookmarks && displayResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 80)
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.placeholder)
                    Text(OrbixStrings.msgNoBookmarked)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
            }

            LazyVStack(spacing: 0, pinnedViews: viewMode == .grid ? .sectionHeaders : []) {
                ForEach(sections, id: \.date) { section in
                    Section {
                        if viewMode == .grid {
                            LazyVGrid(columns: gridColumns, spacing: 1) {
                                ForEach(section.items) { torrent in
                                    TorrentCard(torrent: torrent)
                                        .onTapGesture { selectedTorrent = torrent }
                                        .contextMenu { cardContextMenu(torrent) }
                                }
                            }
                        } else {
                            LazyVStack(spacing: AppSpacing.sm) {
                                ForEach(section.items) { torrent in
                                    ScrapedTorrentRow(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedTorrent = torrent }
                                        .contextMenu { cardContextMenu(torrent) }
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                        }
                    } header: {
                        HStack {
                            Spacer()
                            Text(section.date)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.label)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.xs)
                                        .fill(.black.opacity(0.65))
                                )
                                .padding(.trailing, 4)
                                .padding(.top, 2)
                        }
                        .padding(.bottom, viewMode == .list ? AppSpacing.sm : 0)
                    }
                }

                if !results.isEmpty, !showingBookmarks {
                    VStack(spacing: 4) {
                        if isLoadingMore {
                            ProgressView().tint(AppColors.accent)
                        } else if hasMorePages {
                            Color.clear
                                .frame(height: 1)
                                .onAppear { loadMore() }
                        } else {
                            Text(OrbixStrings.msgAllLoaded)
                                .font(.caption)
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .refreshable { await refreshSearch() }
        .animation(.none, value: results.count)
        .gesture(viewMode == .grid ? pinchToZoom : nil)
    }

    // MARK: - Context Menu
    private func cardContextMenu(_ torrent: ScrapedTorrent) -> some View {
        Group {
            Button { addMagnet(torrent) } label: { Label(OrbixStrings.btnAddToQueue, systemImage: "square.and.arrow.down") }
            Button { toggleBookmark(torrent) } label: {
                Label(bookmarks.contains(torrent.code) ? OrbixStrings.miscUnbookmark : OrbixStrings.miscBookmark,
                      systemImage: bookmarks.contains(torrent.code) ? "heart.fill" : "heart")
            }
            Button { UIPasteboard.general.string = torrent.magnet } label: { Label(OrbixStrings.btnCopyMagnet, systemImage: "doc.on.doc") }
        }
    }

    // MARK: - Data
    private func loadLatest() {
        Task {
            state = .loading
            currentPage = 5
            hasMorePages = true
            do {
                let items = try await TorrentSearchService.shared.newTorrents(pages: 5, startPage: 1)
                await MainActor.run {
                    allResults = items
                    results = items
                    state = items.isEmpty ? .idle : .results
                }
            } catch {
                await MainActor.run { state = .idle }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            allResults = []
            showingBookmarks = false
            loadLatest()
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled { await runSearch() }
        }
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { await MainActor.run { state = .idle }; return }

        await MainActor.run { state = .loading; hasMorePages = true }
        do {
            let items = try await TorrentSearchService.shared.search(query: q, pages: 5, startPage: 1)
            await MainActor.run {
                allResults = items
                results = items
                currentPage = 5
                state = items.isEmpty ? .empty : .results
            }
        } catch {
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    @Sendable private func refreshSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        do {
            let items: [ScrapedTorrent]
            if q.isEmpty {
                items = try await TorrentSearchService.shared.newTorrents(pages: 5, startPage: 1)
            } else {
                items = try await TorrentSearchService.shared.search(query: q, pages: 5, startPage: 1)
            }
            await MainActor.run {
                let existingCodes = Set(results.map(\.code))
                let newItems = items.filter { !existingCodes.contains($0.code) }
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    if !newItems.isEmpty {
                        results = newItems + results
                        allResults = newItems + allResults
                    }
                    currentPage = 5
                    hasMorePages = true
                }
            }
        } catch {
#if DEBUG
            print("[SearchView] refreshSearch error: \(error)")
#endif
        }
    }

    private func loadMore() {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        let q = query.trimmingCharacters(in: .whitespaces)
        let searchQuery = q.isEmpty ? "" : q
        let nextPage = currentPage + 1
        Task {
            do {
                let items: [ScrapedTorrent]
                if searchQuery.isEmpty {
                    items = try await TorrentSearchService.shared.newTorrents(pages: 1, startPage: nextPage)
                } else {
                    items = try await TorrentSearchService.shared.search(query: searchQuery, pages: 1, startPage: nextPage)
                }
                await MainActor.run {
                    if items.isEmpty {
                        hasMorePages = false
                    } else {
                        let existingCodes = Set(results.map(\.code))
                        let newItems = items.filter { !existingCodes.contains($0.code) }
                        if newItems.isEmpty {
                            hasMorePages = false
                        } else {
                            allResults.append(contentsOf: newItems)
                            results.append(contentsOf: newItems)
                            currentPage = nextPage
                        }
                    }
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run { isLoadingMore = false }
            }
        }
    }

    private func addMagnet(_ torrent: ScrapedTorrent) {
        Task { try? await QBitApi.shared.addMagnet([torrent.magnet]) }
    }

    private func toggleBookmark(_ torrent: ScrapedTorrent) {
        if bookmarks.contains(torrent.code) { bookmarks.remove(torrent.code) }
        else { bookmarks.insert(torrent.code) }
        saveBookmarks()
    }

    private func loadBookmarks() {
        bookmarks = Set(PersistenceService.shared.loadBookmarks())
    }

    private func saveBookmarks() {
        PersistenceService.shared.saveBookmarks(Array(bookmarks))
    }

    // MARK: - Shared Components
    private func emptyHint(_ text: String, icon: String, isError: Bool = false) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 48))
                .foregroundColor(isError ? AppColors.danger : AppColors.placeholder)
            Text(text).subtitle(isError ? AppColors.danger : AppColors.secondaryLabel)
        }
    }

    private var gridSkeleton: some View {
        LazyVGrid(columns: gridColumns, spacing: 1) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.card.opacity(0.5))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

#if DEBUG
#Preview {
    SearchView()
}
#endif




