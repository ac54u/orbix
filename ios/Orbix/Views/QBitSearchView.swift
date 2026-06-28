import SwiftUI

// MARK: - 搜索数据源
enum SearchSource: String, CaseIterable {
    case qBittorrent = "qB"
    case prowlarr = "Prowlarr"
    case radarr = "Radarr"

    var label: String {
        switch self {
        case .qBittorrent: return "内置搜索"
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

// MARK: - 下载配置
struct AddTorrentOptions {
    let result: SearchResult
    var category: String = ""
    var savePath: String = ""
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
    @State private var addOptions: AddTorrentOptions?
    @State private var showDownloadSheet = false
    @State private var searchSource: SearchSource = .qBittorrent
    @State private var searchError: String?

    @State private var showRadarrSheet = false
    @State private var radarrResult: SearchResult?
    @State private var qualityProfiles: [RadarrApi.QualityProfile] = []
    @State private var rootFolders: [RadarrApi.RootFolder] = []
    @State private var selectedQualityId = 0
    @State private var selectedRootPath = ""

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
                            Text("正在全网检索...")
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
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(AppColors.secondaryLabel)
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
                            Text("未找到相关资源")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                        }
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("探索")
            .searchable(text: $query, placement: .automatic, prompt: "输入关键字或 Hash...")
            .onChange(of: query) { _, _ in debounceSearch() }
            .onAppear {
                loadPlugins()
                loadCategories()
            }
            .sheet(isPresented: $showDownloadSheet) {
                if let options = addOptions {
                    downloadSheet(options: options)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showRadarrSheet) {
                radarrAddSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Radarr 添加弹窗
    private var radarrAddSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header — poster + info
                    if let item = radarrResult {
                        HStack(alignment: .top, spacing: 14) {
                            AsyncImage(url: URL(string: item.siteUrl)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    ZStack {
                                        Color(uiColor: .secondarySystemBackground)
                                        Image(systemName: "film").foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                            }
                            .frame(width: 80, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.fileName)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.label)
                                Text("TMDB ID: \(item.num)")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.card)
                        )
                    }

                    // Config — quality + root folder
                    VStack(spacing: 0) {
                        if qualityProfiles.isEmpty {
                            HStack {
                                Text("质量配置").font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                ProgressView().controlSize(.mini)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        } else {
                            HStack {
                                Text("质量配置").font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                Picker("", selection: $selectedQualityId) {
                                    ForEach(qualityProfiles) { p in
                                        Text(p.name).tag(p.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 2)
                        }

                        Divider().background(AppColors.separator)

                        if rootFolders.isEmpty {
                            HStack {
                                Text("存储路径").font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                ProgressView().controlSize(.mini)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        } else {
                            HStack {
                                Text("存储路径").font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                Picker("", selection: $selectedRootPath) {
                                    ForEach(rootFolders) { f in
                                        Text(f.path).tag(f.path)
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 2)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.card)
                    )

                    // Add button
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        confirmRadarrAdd()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加并自动搜刮")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.accent)
                        )
                    }
                    .padding(.top, 4)

                    Text("电影添加到库后将自动搜索并开始下载")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(AppColors.mainBg)
            .navigationTitle("添加到 Radarr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showRadarrSheet = false }
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
    }

    private func confirmRadarrAdd() {
        guard let item = radarrResult else { return }
        let name = item.fileName
        let title: String
        let year: Int
        if let paren = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), paren < close {
            let yearStr = String(name[name.index(after: paren)..<close])
            title = String(name[..<paren]).trimmingCharacters(in: .whitespaces)
            year = Int(yearStr) ?? Calendar.current.component(.year, from: Date())
        } else {
            title = name
            year = Calendar.current.component(.year, from: Date())
        }
        Task {
            do {
                try await RadarrApi.addMovie(
                    tmdbId: item.num,
                    title: title,
                    year: year,
                    qualityProfileId: selectedQualityId,
                    rootFolderPath: selectedRootPath,
                    monitored: true,
                    searchOnAdd: true
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await MainActor.run { showRadarrSheet = false }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - 半屏下载弹窗
    private func downloadSheet(options: AddTorrentOptions) -> some View {
        let categoryBinding = Binding(
            get: { self.addOptions?.category ?? "" },
            set: { self.addOptions?.category = $0 }
        )
        let pathBinding = Binding(
            get: { self.addOptions?.savePath ?? "" },
            set: { self.addOptions?.savePath = $0 }
        )

        return NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(options.result.fileName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.label)
                            .lineLimit(2)
                        Text(formatBytes(Int64(options.result.fileSize)))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("种子信息")
                }

                Section {
                    if categories.isEmpty {
                        HStack {
                            Text("下载分类")
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Text("无可用分类")
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    } else {
                        Picker("下载分类", selection: categoryBinding) {
                            Text("无分类").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }

                    HStack {
                        Text("保存路径")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("默认路径", text: pathBinding)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                } header: {
                    Text("下载设置")
                } footer: {
                    Text("留空则使用 qBittorrent 默认下载路径")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showDownloadSheet = false }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定下载") { confirmDownload() }
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accent)
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
                        .foregroundColor(searchSource == source ? .white : AppColors.secondaryLabel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(searchSource == source ? AppColors.accent : AppColors.elevated)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 极简插件栏
    private var pluginBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pluginChip("all", label: "全部")
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
                .foregroundColor(selected ? .white : AppColors.label)
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
                        Text("\(results.count) 个结果")
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
                    resultCard(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 结果卡片
    private func resultCard(_ item: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Text(item.fileName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(item.isAdded ? AppColors.secondaryLabel : AppColors.label)
                    .lineLimit(2)
                if item.isAdded {
                    Text("已在库中")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.success.opacity(0.12))
                        )
                }
            }

            HStack(spacing: 16) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.secondaryLabel)

                if item.nbSeeders > 0 {
                    Label("\(item.nbSeeders)", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.success)
                }

                if item.nbLeechers > 0 {
                    Label("\(item.nbLeechers)", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.danger)
                }

                Spacer()

                if item.isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.success.opacity(0.5))
                        .padding(8)
                        .background(
                            Circle().fill(AppColors.success.opacity(0.1))
                        )
                } else {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        if searchSource == .radarr {
                            radarrResult = item
                            Task {
                                let p = (try? await RadarrApi.getQualityProfiles()) ?? []
                                let r = (try? await RadarrApi.getRootFolders()) ?? []
                                await MainActor.run {
                                    qualityProfiles = p
                                    rootFolders = r
                                    selectedQualityId = p.first?.id ?? 0
                                    selectedRootPath = r.first?.path ?? ""
                                    showRadarrSheet = true
                                }
                            }
                        } else {
                            addOptions = AddTorrentOptions(result: item)
                            showDownloadSheet = true
                        }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .padding(8)
                            .background(
                                Circle().fill(AppColors.accent.opacity(0.1))
                            )
                    }
                }
            }

            if !item.siteUrl.isEmpty {
                Text(item.siteUrl)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.tertiaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
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

    private func confirmDownload() {
        guard let options = addOptions else { return }
        Task {
            do {
                _ = try await QBitApi.shared.addMagnet(
                    [options.result.descr],
                    category: options.category.isEmpty ? nil : options.category,
                    savePath: options.savePath.isEmpty ? nil : options.savePath
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await MainActor.run { showDownloadSheet = false }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - 搜索逻辑
    private func debounceSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchId = nil
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
                searchError = "内置搜索失败: \(error.localizedDescription)"
            }
        }
    }

    private func runProwlarrSearch() async {
        do {
            let items = try await ProwlarrApi.search(query: query)
            await MainActor.run {
                self.results = items.sorted { $0.nbSeeders > $1.nbSeeders }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                searchError = "Prowlarr 连接失败: \(error.localizedDescription)"
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
                searchError = "Radarr 连接失败: \(error.localizedDescription)"
            }
        }
    }
}
