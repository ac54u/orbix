import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var isLoading = true
    @State private var serverOnline: Bool?
    @State private var serverHttps: Bool = false

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService

    var body: some View {
        NavigationStack {
            List {
                if !isLoading {
                    Section {
                        serverProfileCard
                    } header: {
                        Text(OrbixStrings.sectionServer.uppercased())
                    }

                    if appLock.isDeviceSupported {
                        Section {
                            appLockToggle
                        } header: {
                            Text(String(localized: "安全", comment: "Security").uppercased())
                        }
                    }

                    Section {
                        updateRow
                        if let release = updateCheck?.latest {
                            releaseCard(release)
                        }
                        if isDownloading {
                            downloadBar
                        }
                    } header: {
                        Text(String(localized: "更新", comment: "Update").uppercased())
                    }

                    Section {
                        aboutRow(icon: "info.circle", label: String(localized: "版本", comment: "Version"), value: appVersion)
                        aboutRow(icon: "number", label: String(localized: "构建号", comment: "Build"), value: buildNumber)
                    } header: {
                        Text(String(localized: "关于", comment: "About").uppercased())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.groupedBg)
            .navigationTitle(OrbixStrings.navSettings)
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Server Profile Card
    private var serverProfileCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 48, height: 48)
                    Text(String(serverName.prefix(1).uppercased()))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(serverName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.label)
                        if serverHttps {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.success)
                        }
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(serverOnline == true ? AppColors.success : (serverOnline == false ? AppColors.danger : AppColors.tertiaryLabel))
                            .frame(width: 7, height: 7)
                        Text(serverOnline == true ? String(localized: "在线", comment: "Online") :
                                serverOnline == false ? String(localized: "离线", comment: "Offline") :
                                String(localized: "检测中…", comment: "Checking"))
                            .font(.system(size: 13))
                            .foregroundColor(serverOnline == true ? AppColors.success : AppColors.secondaryLabel)
                    }
                }

                Spacer()
            }

            Divider()

            VStack(spacing: 0) {
                HStack {
                    Text(OrbixStrings.sectionAddress)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    Text(serverURL)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 8)
                Divider()

                if !serverVersion.isEmpty {
                    HStack {
                        Text(OrbixStrings.miscQBVersion)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        Text(serverVersion)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }

                HStack {
                    Text(OrbixStrings.sectionUser)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    Text(username)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.vertical, 8)
            }
        }
        .contextMenu {
            if !serverURL.isEmpty {
                Button {
                    UIPasteboard.general.string = serverURL
                } label: {
                    Label(String(localized: "复制地址", comment: "Copy address"), systemImage: "doc.on.doc")
                }
            }
            Button(role: .destructive) {
                logout()
            } label: {
                Label(OrbixStrings.btnSwitchServer, systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Security
    private var appLockToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $appLock.isEnabled) {
                Text(String(localized: "应用锁", comment: "App lock"))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.label)
            }
            .tint(AppColors.accent)

            if appLock.isEnabled {
                Text(String(localized: "切到后台 \(Int(AppConstants.lockGracePeriod)) 秒后自动锁定", comment: "Auto-lock hint"))
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
    }

    // MARK: - Update
    private var updateRow: some View {
        Button {
            checkUpdate()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if isCheckingUpdate {
                        ProgressView().scaleEffect(0.8)
                    } else if let check = updateCheck, check.latest != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.warning)
                    } else if updateCheck?.error != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.danger)
                    } else if updateCheck != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .font(.system(size: 15))
                .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(updateStatusText)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.label)
                    if let detail = updateStatusDetail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .disabled(isCheckingUpdate)
    }

    private var updateStatusText: String {
        if isCheckingUpdate { return OrbixStrings.btnCheckUpdate }
        if updateCheck?.latest != nil { return OrbixStrings.miscUpdateAvailable }
        if updateCheck?.error != nil { return OrbixStrings.btnRetry }
        if updateCheck != nil { return OrbixStrings.btnCheckUpdate }
        return OrbixStrings.btnCheckUpdate
    }

    private var updateStatusDetail: String? {
        if isCheckingUpdate { return nil }
        if updateCheck?.latest != nil { return nil }
        if updateCheck?.error != nil { return nil }
        if updateCheck != nil { return OrbixStrings.msgUpToDate }
        return nil
    }

    private func releaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(release.version)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.label)
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.elevated))
                }
            }

            let cleanNotes = release.notes
                .replacingOccurrences(of: "\\[[^\\]]+\\]\\([^)]+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNotes.isEmpty {
                Text(cleanNotes)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                    .lineLimit(3)
            }

            Button {
                downloadUpdate(release)
            } label: {
                Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent))
            }
            .disabled(isDownloading)
        }
    }

    private var downloadBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: max(4, geo.size.width * downloadProgress))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(AppColors.separator))
                    .animation(.easeOut(duration: 0.3), value: downloadProgress)
            }
            .frame(height: 4)
            Text("\(min(99, Int(downloadProgress * 100)))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - About
    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppColors.tertiaryLabel)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.label)
            Spacer()
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(AppColors.secondaryLabel)
        }
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            let configForTest = config
            let sR = await {
                guard let cfg = configForTest else { return nil as CredentialsManager.TestResult? }
                return await CredentialsManager.testConnection(
                    kind: .qBittorrent, host: cfg.host, port: cfg.port, https: cfg.https,
                    username: cfg.username, password: cfg.password
                )
            }()

            await MainActor.run {
                appVersion = version
                buildNumber = build
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
                serverHttps = config?.https ?? false
                serverOnline = sR?.isSuccess
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
                    Task { @MainActor in downloadProgress = progress }
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
        guard let win = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let w = win.windows.first, let root = w.rootViewController else { return }
        root.present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
    }
}

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
}
#endif
