import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TorrentListView()
                .tabItem {
                    Image(systemName: "square.stack")
                    Text("Torrents")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(1)

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
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
    }
}
