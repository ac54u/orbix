import SwiftUI

struct QBitSearchView: View {
    @State private var query = ""
    @State private var plugins: [SearchPlugin] = []
    @State private var results: [SearchResult] = []
    @State private var selectedPlugins: Set<String> = ["all"]
    @State private var searchId: Int?
    @State private var status: String?
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    pluginBar
                        .padding(.vertical, 12)

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
            .onAppear { loadPlugins() }
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
            Text(item.fileName)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.label)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.secondaryLabel)

                Label("\(item.nbSeeders)", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.success)

                Label("\(item.nbLeechers)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.danger)

                Spacer()

                Button {
                    Task {
                        try? await QBitApi.shared.addMagnet([item.descr])
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
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

    // MARK: - 搜索逻辑
    private func loadPlugins() {
        Task {
            if let list = try? await QBitApi.shared.getSearchPlugins() {
                await MainActor.run { plugins = list }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchId = nil
            results = []
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
        await MainActor.run { isLoading = true; results = [] }
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

                // 轮询期间实时拉取结果，瀑布流式更新
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
            await MainActor.run { isLoading = false }
        }
    }
}
