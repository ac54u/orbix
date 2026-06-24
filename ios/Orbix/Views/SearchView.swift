import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [ScrapedTorrent] = []
    @State private var isLoading = false
    @State private var state: SearchState = .idle
    @State private var bookmarks: [String] = []
    @State private var selectedTorrent: ScrapedTorrent?
    @State private var showMediaViewer = false
    @State private var mediaViewerIndex = 0

    enum SearchState {
        case idle
        case loading
        case results
        case empty
        case error(String)
    }

    private let debounceQueue = DispatchQueue.main

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()

                switch state {
                case .idle:
                    idleView
                case .loading:
                    VStack {
                        ProgressView()
                            .tint(AppColors.accent)
                        Text("搜索中...")
                            .subtitle()
                            .padding(.top, 12)
                    }
                case .results:
                    resultsGrid
                case .empty:
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)
                        Text("未找到结果")
                            .subtitle()
                    }
                case .error(let msg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.danger)
                        Text(msg)
                            .subtitle(AppColors.danger)
                    }
                }
            }
            .navigationTitle("搜索")
            .onAppear { loadBookmarks() }
            .sheet(item: $selectedTorrent) { torrent in
                TorrentDetailSheet(torrent: torrent)
            }
            .fullScreenCover(isPresented: $showMediaViewer) {
                if let thumb = selectedTorrent?.thumbnail {
                    MediaViewer(images: [thumb], initialIndex: 0)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                searchBar
            }
        }
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.placeholder)
                    TextField("搜索 torrent...", text: $query)
                        .bodyFont()
                        .autocapitalization(.none)
                        .onChange(of: query) { _ in
                            debounceSearch()
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            state = .idle
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.card)
                )

                Button {
                    loadBookmarks()
                } label: {
                    Image(systemName: bookmarks.isEmpty ? "heart" : "heart.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.groupedBg)
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("浏览热门")
                .sectionHeader()
                .padding(.horizontal, 36)
                .padding(.top, 16)

            if !bookmarks.isEmpty {
                Section("收藏") {
                    // Bookmark list would go here
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
                ForEach(results) { torrent in
                    TorrentCard(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                        .onTapGesture {
                            selectedTorrent = torrent
                        }
                        .contextMenu {
                            Button {
                                addMagnet(torrent)
                            } label: {
                                Label("添加到队列", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                toggleBookmark(torrent)
                            } label: {
                                Label(
                                    bookmarks.contains(torrent.code) ? "取消收藏" : "收藏",
                                    systemImage: bookmarks.contains(torrent.code) ? "heart.fill" : "heart"
                                )
                            }
                            Button {
                                UIPasteboard.general.string = torrent.magnet
                            } label: {
                                Label("复制 Magnet", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .refreshable {
            await search()
        }
    }

    private func debounceSearch() {
        debounceQueue.cancelPreviousPerformRequests(withTarget: self)
        debounceQueue.perform(#selector(doSearch), with: nil, afterDelay: 0.4)
    }

    @objc private func doSearch() {
        Task { await search() }
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                results = []
                state = .idle
            }
            return
        }

        await MainActor.run { state = .loading }

        do {
            let scraped = try await TorrentSearchService.shared.search(query: query)
            await MainActor.run {
                results = scraped
                state = scraped.isEmpty ? .empty : .results
            }
        } catch {
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    private func addMagnet(_ torrent: ScrapedTorrent) {
        Task {
            try? await QBitApi.shared.addMagnet([torrent.magnet])
        }
    }

    private func toggleBookmark(_ torrent: ScrapedTorrent) {
        let isNow = PersistenceService.shared.toggleBookmark(torrent.code)
        loadBookmarks()
    }

    private func loadBookmarks() {
        bookmarks = PersistenceService.shared.loadBookmarks()
    }
}

private struct TorrentCard: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: torrent.thumbnail ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle()
                            .fill(AppColors.card)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(AppColors.placeholder)
                            }
                    @unknown default:
                        Rectangle().fill(AppColors.card)
                    }
                }
                .frame(height: 120)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack {
                    Text(torrent.size)
                        .caption(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                    if isBookmarked {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(6)

                if !torrent.date.isEmpty {
                    Text(torrent.date)
                        .caption(.white.opacity(0.8))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: -24)
                }
            }

            Text(torrent.title)
                .subtitle()
                .lineLimit(2)
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct TorrentDetailSheet: View {
    let torrent: ScrapedTorrent
    @Environment(\.dismiss) private var dismiss

    @State private var translatedDescription: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let thumb = torrent.thumbnail {
                        AsyncImage(url: URL(string: thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                Rectangle()
                                    .fill(AppColors.card)
                                    .frame(height: 200)
                            }
                        }
                    }

                    Text(torrent.title)
                        .cardTitle()

                    HStack(spacing: 16) {
                        Label(torrent.size, systemImage: "doc")
                            .caption()
                        Label(torrent.date, systemImage: "calendar")
                            .caption()
                    }

                    if let desc = translatedDescription ?? torrent.description {
                        Text(desc)
                            .subtitle()
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                try? await QBitApi.shared.addMagnet([torrent.magnet])
                                dismiss()
                            }
                        } label: {
                            Label("添加到队列", systemImage: "square.and.arrow.down")
                                .bodyFont(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.accent)
                                )
                        }

                        Button {
                            UIPasteboard.general.string = torrent.magnet
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.title3)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.accent, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(AppColors.groupedBg)
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            translate()
        }
    }

    private func translate() {
        guard let desc = torrent.description, !desc.isEmpty else { return }
        Task {
            let translated = try? await TranslateService.shared.toChinese(desc)
            await MainActor.run { translatedDescription = translated }
        }
    }
}
