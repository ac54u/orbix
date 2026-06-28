import SwiftUI

struct SplashView: View {
    let onDecision: (ContentView.Destination) -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            VStack(spacing: 20) {
                GlowingLogo(size: 88)
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0)

                Text("Orbix")
                    .largeTitle()
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)

                ProgressView()
                    .tint(AppColors.secondaryLabel)
                    .padding(.top, 40)
                    .opacity(isAnimating ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await decideDestination()
            }
        }
    }

    private func decideDestination() async {
        // Migrate existing qBittorrent servers into CredentialsManager
        if CredentialsManager.shared.qBittorrent == nil {
            let servers = await QBitApi.shared.loadServers()
            if let saved = await QBitApi.shared.loadSavedConfig() ?? servers.first {
                let cred = ServiceCredential(
                    kind: .qBittorrent, name: saved.name, host: saved.host,
                    port: saved.port, https: saved.https, apiKey: "",
                    username: saved.username, password: saved.password
                )
                CredentialsManager.shared.save(cred)
            }
        }

        // 1. No services at all → first launch
        if CredentialsManager.shared.activeServices.isEmpty {
            onDecision(.welcome)
            return
        }

        // 2. qBittorrent configured → try connect
        let servers = await QBitApi.shared.loadServers()
        if !servers.isEmpty, let active = await QBitApi.shared.loadSavedConfig() {
            await QBitApi.shared.setActiveServer(active)
            let result = await QBitApi.shared.connect()
            if result.isSuccess {
                onDecision(.main)
                return
            }
            // qBittorrent failed → show server selection for fix
            onDecision(.serverSelection)
            return
        }

        // 3. Other services exist but no qBittorrent → still let user in
        onDecision(.main)
    }
}
