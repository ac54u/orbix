import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var isLoading = true

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        SkeletonBar(height: 100)
                        SkeletonBar(height: 72)
                        SkeletonBar(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            serverSectionHeader
                            serverCard

                            securitySectionHeader
                            securityCard

                            updateSectionHeader
                            updateCard

                            Color.clear.frame(height: 80)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Section Headers
    private var serverSectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text("服务器").sectionHeader()
            Spacer()
        }
    }

    private var securitySectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text("安全").sectionHeader()
            Spacer()
        }
    }

    @ViewBuilder
    private var updateSectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text("更新").sectionHeader()
            Spacer()
        }
    }

    // MARK: - Server Card
    private var serverCard: some View {
        VStack(spacing: 0) {
            // Header row — server name + HTTPS badge
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "server.rack")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(serverName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.label)
                    HStack(spacing: 4) {
                        Image(systemName: serverURL.hasPrefix("https") ? "lock.fill" : "lock.open")
                            .font(.caption2)
                            .foregroundColor(serverURL.hasPrefix("https") ? AppColors.success : AppColors.warning)
                        Text(serverURL)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(AppColors.tertiaryLabel)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Divider + details
            Divider()
                .background(AppColors.separator)
                .padding(.top, 14)

            if !serverVersion.isEmpty {
                serverInfoRow(icon: "cube", label: "qBittorrent", value: serverVersion)
                Divider().background(AppColors.separator)
            }

            serverInfoRow(icon: "person", label: "用户", value: username)

            Divider().background(AppColors.separator)

            // Logout button
            Button {
                logout()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("切换服务器")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .foregroundColor(AppColors.danger)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Security Card
    @ViewBuilder
    private var securityCard: some View {
        if appLock.isDeviceSupported {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.accent.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: appLock.hasFaceID ? "faceid" : "touchid")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appLock.hasFaceID ? "Face ID" : "生物识别")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.label)
                            if appLock.isEnabled {
                                Text("已启用")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.success)
                            } else {
                                Text("已关闭")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $appLock.isEnabled)
                        .labelsHidden()
                        .tint(AppColors.accent)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appLock.isEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if appLock.isEnabled {
                    Divider().background(AppColors.separator)
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Text("应用进入后台超过 8 秒后将自动锁定")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Update Card
    private var updateCard: some View {
        VStack(spacing: 0) {
            // Version row
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.success.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.success)
                    }
                    Text("当前版本")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Text("v\(appVersion)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(AppColors.separator)

            // Check update row
            Button {
                checkUpdate()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 32, height: 32)
                        if isCheckingUpdate {
                            ProgressView()
                                .tint(AppColors.accent)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    Text("检查更新")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    if !isCheckingUpdate {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(isCheckingUpdate)

            // Update result
            if let check = updateCheck {
                Divider().background(AppColors.separator)

                if let release = check.latest {
                    updateReleaseCard(release)
                        .padding(12)
                } else if let error = check.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                        Text("检查失败: \(error)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                            .font(.system(size: 14))
                        Text("已是最新版本")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.success)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            // Download progress
            if isDownloading {
                Divider().background(AppColors.separator)
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(AppColors.separator)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accent)
                                .frame(width: geo.size.width * downloadProgress)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("正在下载...")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Spacer()
                        Text("\(min(99, Int(downloadProgress * 100)))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Sub-Components
    private func serverInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AppColors.tertiaryLabel)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func updateReleaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accent)
                Text("v\(release.version)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text("可用")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.15))
                    )
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }

            if !release.notes.isEmpty {
                Text(release.notes)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                    .lineLimit(4)
                    .lineSpacing(2)
            }

            Button {
                downloadUpdate(release)
            } label: {
                HStack {
                    Spacer()
                    if isDownloading {
                        Text("下载中...")
                    } else {
                        Label("下载并安装", systemImage: "icloud.and.arrow.down")
                    }
                    Spacer()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent)
                )
            }
            .disabled(isDownloading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.accentSoftBg)
        )
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            await MainActor.run {
                appVersion = version
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
                isLoading = false
            }
        }
    }

    private func logout() {
        Task {
            await QBitApi.shared.setActiveServer(ServerConfig(
                name: "", host: "", port: 0, username: "", password: "", https: false
            ))
        }
        onLogout()
    }

    private func checkUpdate() {
        isCheckingUpdate = true
        Task {
            let check = await UpdateService.shared.check()
            await MainActor.run {
                updateCheck = check
                isCheckingUpdate = false
            }
        }
    }

    private func downloadUpdate(_ release: AppRelease) {
        isDownloading = true
        downloadProgress = 0

        Task {
            do {
                let url = try await UpdateService.shared.downloadIpa(release) { progress in
                    Task { @MainActor in
                        downloadProgress = progress
                    }
                }
                await MainActor.run {
                    isDownloading = false
                    shareIpa(url)
                }
            } catch {
                await MainActor.run { isDownloading = false }
            }
        }
    }

    private func shareIpa(_ url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return }

        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}
