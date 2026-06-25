import SwiftUI

struct ContentView: View {
    @State private var destination: Destination = .splash
    @State private var showLoginFromWelcome = false
    @State private var deepLinkTab: Int?

    enum Destination {
        case splash
        case welcome
        case serverSelection
        case main
    }

    var body: some View {
        VStack(spacing: 0) {
            switch destination {
            case .splash:
                SplashView(onDecision: { decision in
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = decision
                    }
                })
            case .welcome:
                WelcomeView(onAddServer: {
                    showLoginFromWelcome = true
                })
                .sheet(isPresented: $showLoginFromWelcome) {
                    LoginView { config in
                        showLoginFromWelcome = false
                        Task {
                            await QBitApi.shared.setActiveServer(config)
                            _ = await QBitApi.shared.connect()
                            await MainActor.run {
                                withAnimation(.smooth(duration: 0.35)) {
                                    destination = .main
                                }
                            }
                        }
                    }
                }
            case .serverSelection:
                ServerSelectionView(onConnected: {
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = .main
                    }
                })
            case .main:
                MainTabView(initialTab: deepLinkTab, onLogout: {
                    deepLinkTab = nil
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = .serverSelection
                    }
                })
            }
        }
        .animation(.smooth(duration: 0.35), value: destination)
        .onOpenURL { _ in
            deepLinkTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in
            deepLinkTab = 2
        }
    }
}
