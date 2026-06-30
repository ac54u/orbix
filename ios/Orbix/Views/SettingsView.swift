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

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

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
                        SkeletonBar(height: 100)
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
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "server.rack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text(OrbixStrings.sectionServer)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.label)
                Spacer()

                if let online = serverOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(online ? AppColors.success : AppColors.danger)
                            .frame(width: 7, height: 7)
                        Text(online ? String(localized: "在线", comment: "Online") : String(localized: "离线", comment: "Offline"))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
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
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: appLock.hasFaceID ? "faceid" : "touchid")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    Text(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.label)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(AppColors.separator)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Toggle(isOn: $appLock.isEnabled) {
                        Text(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                    }
                    .tint(AppColors.accent)

                    if appLock.isEnabled {
                        Text(String(format: String(localized: "切到后台 %d 秒后锁定", comment: "Lock after X seconds"), Int(AppConstants.lockGracePeriod)))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
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
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    Text(OrbixStrings.sectionServices)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.label)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(AppColors.separator)

                ForEach(list) { cred in
                    Button {
                        editingCred = cred
                        showAddService = true
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: cred.kind.icon)
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(cred.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.label)
                                Text("\(cred.host):\(cred.port)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppColors.tertiaryLabel)
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
                            .foregroundColor(AppColors.accent)
                        Text(OrbixStrings.navAddService)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.accent)
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
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text(OrbixStrings.sectionUpdate)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.label)
                if !appVersion.isEmpty {
                    Text("v\(appVersion)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(AppColors.separator)

            Button {
                checkUpdate()
            } label: {
                HStack {
                    HStack(spacing: AppSpacing.xs) {
                        if isCheckingUpdate {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppColors.accent)
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
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text(String(localized: "关于", comment: "About"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.label)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(AppColors.separator)

            infoRow(icon: "tag", label: String(localized: "版本", comment: "Version"), value: appVersion)

            if !buildNumber.isEmpty {
                infoRow(icon: "hammer", label: String(localized: "构建号", comment: "Build"), value: buildNumber)
            }
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
                        .fill(AppColors.accent)
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
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Shared components
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
                        .fill(AppColors.accent)
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

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
}
#endif
