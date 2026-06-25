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
    @State private var lastPage = 1

    enum SearchState { case idle, loading, results, empty, error(String) }

    @State private var searchTask: Task<Void, Never>?
    @State private var searchIconTapCount = 0
    @State private var showEasterEgg = false

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
            .fullScreenCover(isPresented: $showEasterEgg) { EasterEggView() }
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
                        .onTapGesture {
                            searchIconTapCount += 1
                            if searchIconTapCount >= 3 {
                                searchIconTapCount = 0
                                showEasterEgg = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { searchIconTapCount = 0 }
                        }
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
                        ForEach(results) { torrent in
                            TorrentCard(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                                .onTapGesture { selectedTorrent = torrent }
                                .contextMenu { cardContextMenu(torrent) }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .refreshable { await refreshSearch() }
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
    private var resultsView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
                ForEach(results) { torrent in
                    TorrentCard(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                        .onTapGesture { selectedTorrent = torrent }
                        .contextMenu { cardContextMenu(torrent) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if !results.isEmpty {
                VStack(spacing: 4) {
                    if isLoadingMore {
                        ProgressView().tint(AppColors.accent)
                    } else if results.count >= 20 {
                        Text("上滑加载更多").font(.caption).foregroundColor(AppColors.tertiaryLabel)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .refreshable { await refreshSearch() }
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
            do {
                let items = try await TorrentSearchService.shared.trending(pages: 2)
                await MainActor.run {
                    allResults = items
                    results = items
                    lastPage = 2
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

        await MainActor.run { state = .loading }
        do {
            let items = try await TorrentSearchService.shared.search(query: q, pages: 5)
            await MainActor.run {
                allResults = items
                results = items
                lastPage = 5
                state = items.isEmpty ? .empty : .results
            }
        } catch {
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    @Sendable private func refreshSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return }
        do {
            let items = try await TorrentSearchService.shared.search(query: q, pages: 3)
            await MainActor.run {
                allResults = items
                results = items
                lastPage = 3
                state = items.isEmpty ? .empty : .results
            }
        } catch {}
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
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48))
                .foregroundColor(isError ? AppColors.danger : AppColors.placeholder)
            Text(text).subtitle(isError ? AppColors.danger : AppColors.secondaryLabel)
        }
    }

    private var gridSkeleton: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10).fill(AppColors.card).frame(height: 200)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Torrent Card
private struct TorrentCard: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool

    var body: some View {
        TweenAnimationBuilder { value in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: torrent.thumbnail ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle().fill(AppColors.card).overlay {
                            Image(systemName: "photo").foregroundColor(AppColors.placeholder)
                        }
                    @unknown default: Rectangle().fill(AppColors.card)
                    }
                }
                .frame(height: 160).clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.code).font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white).lineLimit(1)
                    Text(torrent.size).font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(8)

                if isBookmarked {
                    Image(systemName: "heart.fill").font(.system(size: 10))
                        .foregroundColor(AppColors.danger)
                        .padding(6).background(Circle().fill(.ultraThinMaterial))
                        .padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                if !torrent.date.isEmpty {
                    Text(torrent.date).font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                        .padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(value).offset(y: 15 * (1 - value))
        }
    }
}

private struct TweenAnimationBuilder<Content: View>: View {
    @State private var anim = false
    let content: (Double) -> Content
    var body: some View {
        content(anim ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: 0.3)) { anim = true } }
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

// MARK: - Easter Egg
private struct EasterEggView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var results: [ScrapedTorrent] = []
    @State private var isLoading = true

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
                    .padding(.horizontal, 20).padding(.top, 20)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48)).foregroundColor(AppColors.placeholder)
                        Text("没有抓到数据").foregroundColor(AppColors.secondaryLabel)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
                            ForEach(results) { torrent in
                                TorrentCard(torrent: torrent, isBookmarked: false)
                            }
                        }
                        .padding(.horizontal, 12).padding(.top, 8)
                        VStack(spacing: 4) {
                            Text("TorrentSearchService 正在工作").font(.caption).foregroundColor(AppColors.secondaryLabel)
                            Text("141ppv · 共 \(results.count) 条").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("🔍 秘密探索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .task {
            do {
                let scraped = try await TorrentSearchService.shared.trending(pages: 2)
                await MainActor.run { results = scraped; isLoading = false }
            } catch { await MainActor.run { isLoading = false } }
        }
    }
}
