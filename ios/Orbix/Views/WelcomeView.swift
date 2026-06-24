import SwiftUI

struct WelcomeView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                GlowingLogo(size: 88)

                Text("Orbix")
                    .largeTitle()

                Text("qBittorrent 客户端")
                    .subtitle()

                VStack(spacing: 12) {
                    FeatureTile(
                        icon: "server.rack",
                        title: "添加服务器",
                        subtitle: "配置你的 qBittorrent 连接"
                    )
                    FeatureTile(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "一键连接",
                        subtitle: "安全稳定地远程管理"
                    )
                    FeatureTile(
                        icon: "square.and.arrow.down.on.square",
                        title: "管理种子",
                        subtitle: "随时随地下载与监控"
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    Text("开始使用")
                        .bodyFont(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.accent)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct FeatureTile: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bodyFont()
                Text(subtitle)
                    .subtitle()
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.card)
        )
    }
}
