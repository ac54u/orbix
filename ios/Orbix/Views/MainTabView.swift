import SwiftUI

final class SearchModeState: ObservableObject {
    @Published var use141: Bool = false
    static let shared = SearchModeState()
}

struct MainTabView: View {
    let initialTab: Int?
    let onLogout: () -> Void

    @State private var selectedTab = 0
    @StateObject private var searchMode = SearchModeState.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            TorrentListView()
                .tabItem {
                    Image(systemName: "square.stack")
                    Text("种子")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("传输")
                }
                .tag(1)

            Group {
                if searchMode.use141 {
                    SearchView()
                } else {
                    QBitSearchView()
                }
            }
            .tabItem {
                Image(systemName: searchMode.use141 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                Text("搜索")
            }
            .tag(2)

            SettingsView(onLogout: onLogout)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(3)
        }
        .tint(AppColors.accent)
        .onAppear {
            if let tab = initialTab { selectedTab = tab }
        }
    }
}
