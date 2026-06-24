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
                AppColors.groupedBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        SkeletonBar(height: 16)
                        SkeletonBar(height: 16)
                        SkeletonBar(height: 16)
                    }
                    .padding(.horizontal, 20)
                } else {
                    List {
                        serverSection
                        securitySection
                        updateSection
                    }
                    .insetGroupedStyle()
                }
            }
            .navigationTitle("设置")
            .onAppear { loadInfo() }
        }
    }

    private var serverSection: some View {
        Section("服务器") {
            HStack {
                Text("名称")
                    .subtitle()
                Spacer()
                Text(serverName)
                    .bodyFont()
            }
            HStack {
                Text("地址")
                    .subtitle()
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: serverURL.hasPrefix("https") ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundColor(serverURL.hasPrefix("https") ? AppColors.success : AppColors.secondaryLabel)
                    Text(serverURL)
                        .bodyFont()
                }
            }
            if !serverVersion.isEmpty {
                HStack {
                    Text("qBittorrent 版本")
                        .subtitle()
                    Spacer()
                    Text(serverVersion)
                        .bodyFont()
                }
            }
            HStack {
                Text("用户")
                    .subtitle()
                Spacer()
                Text(username)
                    .bodyFont()
            }

            Button {
                logout()
            } label: {
                HStack {
                    Spacer()
                    Text("切换服务器")
                        .bodyFont(AppColors.danger)
                    Spacer()
                }
            }
        }
    }

    private var securitySection: some View {
        Section {
            if appLock.isDeviceSupported {
                Toggle(isOn: $appLock.isEnabled) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(AppColors.accent)
                        Text(appLock.hasFaceID ? "Face ID" : "生物识别")
                            .bodyFont()
                    }
                }
                .tint(AppColors.accent)
            }
        } header: {
            Text("安全")
        } footer: {
            if appLock.isEnabled {
                Text("应用进入后台超过 8 秒后将自动锁定")
                    .font(AppTypography.caption())
            }
        }
    }

    private var updateSection: some View {
        Section("更新") {
            HStack {
                Text("当前版本")
                    .subtitle()
                Spacer()
                Text("v\(appVersion)")
                    .bodyFont()
            }

            Button {
                checkUpdate()
            } label: {
                HStack {
                    Text("检查更新")
                        .bodyFont()
                    Spacer()
                    if isCheckingUpdate {
                        ProgressView()
                            .tint(AppColors.accent)
                    }
                }
            }
            .disabled(isCheckingUpdate)

            if let check = updateCheck {
                if let release = check.latest {
                    updateCard(release)
                } else if let error = check.error {
                    Text("检查失败: \(error)")
                        .caption(AppColors.danger)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("已是最新版本")
                            .subtitle()
                    }
                }
            }

            if isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .tint(AppColors.accent)
                    Text("\(Int(downloadProgress * 100))%")
                        .caption()
                }
            }
        }
    }

    private func updateCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(AppColors.accent)
                Text("v\(release.version) 可用")
                    .bodyFont(AppColors.accent)
                Spacer()
                if let size = release.ipaSize {
                    Text(formattedSize(size))
                        .caption()
                }
            }

            if !release.notes.isEmpty {
                Text(release.notes)
                    .subtitle()
                    .lineLimit(4)
            }

            Button {
                downloadUpdate(release)
            } label: {
                HStack {
                    Spacer()
                    Text(isDownloading ? "下载中..." : "下载并安装")
                        .bodyFont(.white)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.accent)
                )
            }
            .disabled(isDownloading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.accentSoftBg)
        )
    }

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

    private func formattedSize(_ bytes: Int64) -> String {
        if bytes >= 1_000_000 { return String(format: "%.1f MB", Double(bytes) / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.1f KB", Double(bytes) / 1_000) }
        return "\(bytes) B"
    }
}
