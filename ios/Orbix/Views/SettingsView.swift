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
    @State private var prowlarrOnline: Bool?
    @State private var radarrOnline: Bool?

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showCacheCleared = false

    @EnvironmentObject private var appLock: AppLockService
    @ObservedObject private var creds = CredentialsManager.shared
    @State private var showAddService = false
    @State private var editingCred: ServiceCredential?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: AppSpacing.md) {
                        SkeletonBar(height: 140)
                        SkeletonBar(height: 56)
                        SkeletonBar(height: 160)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            serverCard
                            securityCard
                            servicesCard
                            updateCard
                            aboutCard
                            Color.clear.frame(height: 80)
                        }
                        .padding(.vertical, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.xl)
                    }
                }
            }
            .navigationTitle(OrbixStrings.navSettings)
            .sheet(isPresented: $showAddService) {
                AddServiceView(existing: editingCred) { cred in
                    creds.save(cred)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Server Card
    private var serverCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "server.rack")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(OrbixStrings.sectionServer)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.label)
                    Text(serverName)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()

                if let online = serverOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(online ? AppColors.success : AppColors.danger)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(online ? AppColors.success : AppColors.danger)
                                    .frame(width: 8, height: 8)
                                    .opacity(online ? 0.4 : 0)
                                    .scaleEffect(online ? 1.5 : 1.0)
                                    .animation(online ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: online)
                            )
                        Text(online ? String(localized: "在线", comment: "Online") : String(localized: "离线", comment: "Offline"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(online ? AppColors.success : AppColors.danger)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(online ? AppColors.success.opacity(0.1) : AppColors.danger.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)

            Divider().background(AppColors.separator)

            infoRow(icon: "network", label: OrbixStrings.sectionAddress, value: serverURL)

            if !serverVersion.isEmpty {
                infoRow(icon: "cube.transparent", label: OrbixStrings.miscQBVersion, value: serverVersion)
            }

            infoRow(icon: "person.fill", label: OrbixStrings.sectionUser, value: username)

            Divider().background(AppColors.separator)

            Button {
                logout()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .medium))
                    Text(OrbixStrings.btnSwitchServer)
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                }
                .foregroundColor(AppColors.danger)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Security Card
    @ViewBuilder
    private var securityCard: some View {
        if appLock.isDeviceSupported {
            VStack(spacing: 0) {
                cardHeader(icon: appLock.hasFaceID ? "faceid" : "touchid",
                           title: appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric,
                           accent: Color(hex: "#8B5CF6"))

                Divider().background(AppColors.separator)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Toggle(isOn: $appLock.isEnabled) {
                        Text(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                    }
                    .tint(Color(hex: "#8B5CF6"))

                    if appLock.isEnabled {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "timer")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.tertiaryLabel)
                            Text(String(format: String(localized: "切到后台 %d 秒后锁定", comment: "Lock after X seconds in background"), Int(AppConstants.lockGracePeriod)))
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Services Card
    @ViewBuilder
    private var servicesCard: some View {
        let list = creds.allCredentials
        if !list.isEmpty {
            VStack(spacing: 0) {
                cardHeader(icon: "antenna.radiowaves.left.and.right",
                           title: OrbixStrings.sectionServices,
                           accent: AppColors.warning)

                Divider().background(AppColors.separator)

                ForEach(list) { cred in
                    HStack(spacing: AppSpacing.md) {
                        serviceIcon(kind: cred.kind)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: 4) {
                                Text(cred.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.label)
                                if cred.kind == .qBittorrent {
                                    Circle()
                                        .fill(serverOnline == true ? AppColors.success : AppColors.danger)
                                        .frame(width: 6, height: 6)
                                } else if cred.kind == .prowlarr {
                                    if let online = prowlarrOnline {
                                        Circle()
                                            .fill(online ? AppColors.success : AppColors.danger)
                                            .frame(width: 6, height: 6)
                                    }
                                } else if cred.kind == .radarr {
                                    if let online = radarrOnline {
                                        Circle()
                                            .fill(online ? AppColors.success : AppColors.danger)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            }
                            Text(cred.kind == .qBittorrent ? "\(cred.host):\(cred.port)" : cred.apiURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.tertiaryLabel)
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Button {
                                editingCred = cred
                                showAddService = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.accent)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Button {
                                creds.remove(cred.kind)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.danger)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)

                    if cred.id != list.last?.id {
                        Divider().background(AppColors.separator)
                    }
                }

                Divider().background(AppColors.separator)

                Button {
                    editingCred = nil
                    showAddService = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.warning)
                        Text(OrbixStrings.navAddService)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.warning)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Update Card
    private var updateCard: some View {
        VStack(spacing: 0) {
            cardHeader(icon: "arrow.down.circle",
                       title: OrbixStrings.sectionUpdate,
                       subtitle: "v\(appVersion)",
                       accent: AppColors.success)

            Divider().background(AppColors.separator)

            Button {
                checkUpdate()
            } label: {
                HStack {
                    HStack(spacing: AppSpacing.xs) {
                        if isCheckingUpdate {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppColors.success)
                        } else if let check = updateCheck, check.latest != nil {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.warning)
                            Text(OrbixStrings.miscUpdateAvailable)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.warning)
                        } else if updateCheck?.error != nil {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.danger)
                            Text(OrbixStrings.btnRetry)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.secondaryLabel)
                        } else if updateCheck != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                            Text(OrbixStrings.msgUpToDate)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.success)
                        } else {
                            Text(OrbixStrings.btnCheckUpdate)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isCheckingUpdate)

            if let check = updateCheck, let release = check.latest {
                Divider().background(AppColors.separator)
                updateReleaseCard(release)
            }

            if isDownloading {
                Divider().background(AppColors.separator)
                downloadProgressBar
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - About Card
    private var aboutCard: some View {
        VStack(spacing: 0) {
            cardHeader(icon: "info.circle",
                       title: String(localized: "关于", comment: "About"),
                       accent: AppColors.tertiaryLabel)

            Divider().background(AppColors.separator)

            infoRow(icon: "tag", label: String(localized: "版本", comment: "Version"), value: appVersion)
            infoRow(icon: "hammer", label: String(localized: "构建号", comment: "Build"), value: buildNumber)

            Divider().background(AppColors.separator)

            Button {
                clearCache()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: showCacheCleared ? "checkmark.circle" : "photo.on.rectangle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(showCacheCleared ? AppColors.success : AppColors.secondaryLabel)
                    Text(showCacheCleared ? String(localized: "已清除", comment: "Cleared") : String(localized: "清除图片缓存", comment: "Clear image cache"))
                        .font(.system(size: 14))
                        .foregroundColor(showCacheCleared ? AppColors.success : AppColors.secondaryLabel)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(showCacheCleared)

            Divider().background(AppColors.separator)

            Button {
                if let url = URL(string: "https://github.com/ac54u/orbix") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "link")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    Text("GitHub")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
    }

    private var downloadProgressBar: some View {
        VStack(spacing: AppSpacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.separator)
                    Capsule()
                        .fill(AppColors.success)
                        .frame(width: max(4, geo.size.width * downloadProgress))
                        .animation(.easeOut(duration: 0.3), value: downloadProgress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(OrbixStrings.msgDownloading)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Text("\(min(99, Int(downloadProgress * 100)))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Shared components
    private func cardHeader(icon: String, title: String, subtitle: String? = nil, accent: Color = AppColors.accent) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.label)
            }

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
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
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 11)
    }

    private func serviceIcon(kind: ServiceKind) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(serviceColor(kind).opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: kind.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(serviceColor(kind))
        }
    }

    private func serviceColor(_ kind: ServiceKind) -> Color {
        switch kind {
        case .qBittorrent: return AppColors.accent
        case .prowlarr: return AppColors.warning
        case .radarr: return Color(hex: "#8B5CF6")
        }
    }

    // MARK: - Update Release Card
    private func updateReleaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.warning)
                Text(release.version)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.label)
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.elevated)
                        )
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
                    .lineLimit(4)
            }

            Button {
                downloadUpdate(release)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: isDownloading ? "arrow.down.circle" : "icloud.and.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                    Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.success)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isDownloading)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.accentSoftBg)
        )
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            let configForTest = config
            async let serverResult: CredentialsManager.TestResult? = {
                guard let cfg = configForTest else { return nil }
                return await CredentialsManager.testConnection(
                    kind: .qBittorrent, host: cfg.host, port: cfg.port, https: cfg.https,
                    username: cfg.username, password: cfg.password
                )
            }()

            async let prowlarrResult: CredentialsManager.TestResult? = {
                guard let pc = await CredentialsManager.shared.prowlarr, !pc.host.isEmpty else { return nil }
                return await CredentialsManager.testConnection(
                    kind: .prowlarr, host: pc.host, port: pc.port, https: pc.https, apiKey: pc.apiKey
                )
            }()

            async let radarrResult: CredentialsManager.TestResult? = {
                guard let rc = await CredentialsManager.shared.radarr, !rc.host.isEmpty else { return nil }
                return await CredentialsManager.testConnection(
                    kind: .radarr, host: rc.host, port: rc.port, https: rc.https, apiKey: rc.apiKey
                )
            }()

            let sR = await serverResult
            let pR = await prowlarrResult
            let rR = await radarrResult

            await MainActor.run {
                appVersion = version
                buildNumber = build
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
                serverOnline = sR?.isSuccess
                prowlarrOnline = pR?.isSuccess
                radarrOnline = rR?.isSuccess
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

    private func clearCache() {
        ImageCache.shared.removeAll()
        URLCache.shared.removeAllCachedResponses()
        showCacheCleared = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { showCacheCleared = false }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
}
#endif
