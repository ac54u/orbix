import SwiftUI

struct WelcomeView: View {
    let onAddServer: () -> Void

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
                        icon: "plus.app.fill",
                        title: "添加服务器",
                        subtitle: "配置你的 qBittorrent 服务器地址"
                    )
                    FeatureTile(
                        icon: "link",
                        title: "建立连接",
                        subtitle: "快速连接到远程或本地服务器"
                    )
                    FeatureTile(
                        icon: "arrow.down.doc.fill",
                        title: "管理种子",
                        subtitle: "轻松管理和监控所有种子任务"
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    onAddServer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加服务器")
                            .bodyFont(.white)
                    }
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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.05 : 0), lineWidth: 0.5)
                )
        )
    }
}
