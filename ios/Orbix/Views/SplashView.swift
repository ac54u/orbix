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
        let servers = await QBitApi.shared.loadServers()

        guard !servers.isEmpty else {
            onDecision(.welcome)
            return
        }

        if let active = await QBitApi.shared.loadSavedConfig() {
            await QBitApi.shared.setActiveServer(active)
            let result = await QBitApi.shared.connect()
            if result.isSuccess {
                onDecision(.main)
                return
            }
        }

        onDecision(.serverSelection)
    }
}
