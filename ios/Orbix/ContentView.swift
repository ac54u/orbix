import SwiftUI

struct ContentView: View {
    @State private var destination: Destination = .splash

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
                WelcomeView(onComplete: {
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = .main
                    }
                })
            case .serverSelection:
                ServerSelectionView(onConnected: {
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = .main
                    }
                })
            case .main:
                MainTabView(onLogout: {
                    withAnimation(.smooth(duration: 0.35)) {
                        destination = .serverSelection
                    }
                })
            }
        }
        .animation(.smooth(duration: 0.35), value: destination)
    }
}
