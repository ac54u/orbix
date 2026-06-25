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

    enum SearchState { case idle, loading, results, empty, error(String) }

    @State private var searchTask: Task<Void, Never>?

    // MARK: - Grid Layout (pinch to zoom)
    @AppStorage("searchGridColumns") private var gridColumnCount = 4
    @State private var pinchBaseColumns: Int?

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
                case .empty: emptyHint("未找到结果", icon: "magnifyingglass")
                case .error(let m): emptyHint(m, icon: "exclamationmark.triangle", isError: true)
                }
            }
            .navigationTitle("搜索")
            .onAppear { loadBookmarks(); if allResults.isEmpty { loadLatest() } }
            .sheet(item: $selectedTorrent) { TorrentDetailSheet(torrent: $0, bookmarks: $bookmarks, onChanged: saveBookmarks) }
            .fullScreenCover(isPresented: $showMediaViewer) {
                let imgs = results.map { $0.thumbnail ?? "" }.filter { !$0.isEmpty }
                if !imgs.isEmpty {
                    MediaViewer(images: imgs, initialIndex: mediaViewerIndex)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.placeholder)
                    TextField("搜索 torrent...", text: $query)
                        .bodyFont()
                        .autocapitalization(.none)
                        .onChange(of: query) { _ in debounceSearch() }
                    if !query.isEmpty {
                        Button { query = ""; results = []; allResults = []; state = .idle } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.card))

                Button {
                    loadBookmarks()
                } label: {
                    Image(systemName: bookmarks.isEmpty ? "heart" : "heart.fill")
                        .foregroundColor(AppColors.accent).font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if case .results = state, !results.isEmpty {
                HStack {
                    Image(systemName: "doc.text").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                    Text(query.isEmpty ? "\(results.count) 条结果" : "「\(query)」· \(results.count) 条")
                        .font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
        }
        .background(AppColors.groupedBg)
    }

    // MARK: - Idle / Trending
    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(AppColors.warning)
                    Text("浏览热门").sectionHeader()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("搜索番号或名称")
                    .subtitle(AppColors.tertiaryLabel)
                    .padding(.horizontal, 20)

                if results.isEmpty {
                    gridSkeleton
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 1) {
                        ForEach(results) { torrent in
                            TorrentCard(torrent: torrent)
                                .onTapGesture { selectedTorrent = torrent }
                                .contextMenu { cardContextMenu(torrent) }
                        }
                    }
                }
            }
        }
        .refreshable { await refreshSearch() }
        .gesture(pinchToZoom)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().tint(AppColors.accent)
                Text("正在获取最新资源...").subtitle(AppColors.tertiaryLabel)
            }
            .padding(.top, 16)
            gridSkeleton
        }
    }

    // MARK: - Results
    private var sections: [(date: String, items: [ScrapedTorrent])] {
        var dict = [String: [ScrapedTorrent]]()
        var order: [String] = []
        for item in results {
            if dict[item.date] == nil { order.append(item.date) }
            dict[item.date, default: []].append(item)
        }
        return order.map { (date: $0, items: dict[$0]!) }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(sections, id: \.date) { section in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 1) {
                            ForEach(section.items) { torrent in
                                TorrentCard(torrent: torrent)
                                    .onTapGesture { selectedTorrent = torrent }
                                    .contextMenu { cardContextMenu(torrent) }
                            }
                        }
                        .padding(.top, 1)
                    } header: {
                        HStack {
                            Spacer()
                            Text(section.date)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.5)))
                                .padding(.trailing, 4)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .background(.clear)
                    }
                }

                if !results.isEmpty {
                    VStack(spacing: 4) {
                        if isLoadingMore {
                            ProgressView().tint(AppColors.accent)
                        } else if hasMorePages {
                            Color.clear
                                .frame(height: 1)
                                .onAppear { loadMore() }
                        } else {
                            Text("— 已加载全部 —")
                                .font(.caption)
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .refreshable { await refreshSearch() }
        .gesture(pinchToZoom)
    }

    // MARK: - Context Menu
    private func cardContextMenu(_ torrent: ScrapedTorrent) -> some View {
        Group {
            Button { addMagnet(torrent) } label: { Label("添加到队列", systemImage: "square.and.arrow.down") }
            Button { toggleBookmark(torrent) } label: {
                Label(bookmarks.contains(torrent.code) ? "取消收藏" : "收藏",
                      systemImage: bookmarks.contains(torrent.code) ? "heart.fill" : "heart")
            }
            Button { UIPasteboard.general.string = torrent.magnet } label: { Label("复制 Magnet", systemImage: "doc.on.doc") }
        }
    }

    // MARK: - Data
    private func loadLatest() {
        Task {
            state = .loading
            currentPage = 3
            hasMorePages = true
            do {
                let items = try await TorrentSearchService.shared.newTorrents(pages: 3, startPage: 1)
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
            let items = try await TorrentSearchService.shared.search(query: q, pages: 3, startPage: 1)
            await MainActor.run {
                allResults = items
                results = items
                currentPage = 3
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
            let page: Int
            if q.isEmpty {
                items = try await TorrentSearchService.shared.newTorrents(pages: 3, startPage: 1)
                page = 3
            } else {
                items = try await TorrentSearchService.shared.search(query: q, pages: 3, startPage: 1)
                page = 3
            }
            await MainActor.run {
                allResults = items
                results = items
                currentPage = page
                hasMorePages = true
                state = items.isEmpty ? .empty : .results
            }
        } catch {}
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

// MARK: - Torrent Card (square photo wall style)
private struct TorrentCard: View {
    let torrent: ScrapedTorrent

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: torrent.thumbnail ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                case .failure, .empty:
                    AppColors.card
                @unknown default:
                    AppColors.card
                }
            }

            // Size badge — Swiftgram Pro style pill at bottom-right
            Text(torrent.size)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding([.bottom, .trailing], 3)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}

// MARK: - Detail Sheet
private struct TorrentDetailSheet: View {
    let torrent: ScrapedTorrent
    @Binding var bookmarks: Set<String>
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var translatedDescription: String?
    @State private var showMediaViewer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let thumb = torrent.thumbnail {
                        AsyncImage(url: URL(string: thumb)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture { showMediaViewer = true }
                            default:
                                Rectangle().fill(AppColors.card).frame(height: 200)
                            }
                        }
                    }

                    Text(torrent.code).cardTitle()
                    if torrent.title != torrent.code {
                        Text(torrent.title).subtitle(AppColors.tertiaryLabel)
                    }

                    HStack(spacing: 16) {
                        Label(torrent.size, systemImage: "doc").caption()
                        Label(torrent.date, systemImage: "calendar").caption()
                    }

                    if let desc = translatedDescription ?? torrent.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(desc).subtitle().textSelection(.enabled)
                            if translatedDescription != nil, let raw = torrent.description {
                                Divider().background(AppColors.separator)
                                HStack {
                                    Image(systemName: "doc.text").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Text("原文（日文）").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                }
                                Text(raw).subtitle().textSelection(.enabled)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.card))
                    }

                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "tag").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                Text("番号").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                Spacer()
                            }
                            HStack {
                                Text(torrent.code).font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.label)
                                Spacer()
                                Button { UIPasteboard.general.string = torrent.code } label: {
                                    Image(systemName: "doc.on.doc").font(.caption2).foregroundColor(AppColors.accent)
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.card))

                        if let pageUrl = torrent.pageUrl {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "link").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Text("页面链接").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Spacer()
                                }
                                HStack {
                                    Text(pageUrl).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.accent).lineLimit(1)
                                    Spacer()
                                    Button { UIPasteboard.general.string = pageUrl } label: {
                                        Image(systemName: "doc.on.doc").font(.caption2).foregroundColor(AppColors.accent)
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.card))
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { try? await QBitApi.shared.addMagnet([torrent.magnet]); dismiss() }
                        } label: {
                            Label("添加到队列", systemImage: "square.and.arrow.down")
                                .bodyFont(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.accent))
                        }

                        Button { UIPasteboard.general.string = torrent.magnet } label: {
                            Label("复制磁力链接", systemImage: "doc.on.doc")
                                .bodyFont(AppColors.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent, lineWidth: 1))
                        }

                        if let torrentUrl = torrent.torrentUrl {
                            Button { downloadTorrent(torrentUrl) } label: {
                                Label("下载 .torrent 文件", systemImage: "arrow.down.doc")
                                    .bodyFont(AppColors.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent, lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBg)
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { toggleBookmark() } label: {
                        Image(systemName: bookmarks.contains(torrent.code) ? "heart.fill" : "heart")
                            .foregroundColor(bookmarks.contains(torrent.code) ? AppColors.danger : AppColors.tertiaryLabel)
                    }
                }
            }
        }
        .onAppear { translate() }
    }

    private func toggleBookmark() {
        if bookmarks.contains(torrent.code) { bookmarks.remove(torrent.code) }
        else { bookmarks.insert(torrent.code) }
        onChanged()
    }

    private func translate() {
        guard let desc = torrent.description, !desc.isEmpty else { return }
        Task {
            let translated = try? await TranslateService.shared.toChinese(desc)
            await MainActor.run { translatedDescription = translated }
        }
    }

    private func downloadTorrent(_ urlStr: String) {
        guard let url = URL(string: urlStr.hasPrefix("http") ? urlStr : "https://www.141ppv.com\(urlStr)") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try data.write(to: temp)
                await MainActor.run {
                    let av = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(av, animated: true)
                    }
                }
            } catch {}
        }
    }
}


