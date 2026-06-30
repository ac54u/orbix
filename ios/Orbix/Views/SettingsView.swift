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
            List {
                if !isLoading {
                    serverSection
                    securitySection
                    servicesSection
                    updateSection
                    aboutSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
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

    // MARK: - Server
    @ViewBuilder
    private var serverSection: some View {
        Section {
            row(icon: "network", label: OrbixStrings.sectionAddress, value: serverURL)
            if !serverVersion.isEmpty {
                row(icon: "cube.transparent", label: OrbixStrings.miscQBVersion, value: serverVersion)
            }
            row(icon: "person.fill", label: OrbixStrings.sectionUser, value: username)
            row(icon: "rectangle.portrait.and.arrow.right",
                label: OrbixStrings.btnSwitchServer,
                value: "",
                tint: AppColors.danger) {
                logout()
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text(serverName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.label)
                Spacer()
                if let online = serverOnline {
                    HStack(spacing: 4) {
                        Circle().fill(online ? AppColors.success : AppColors.danger).frame(width: 6, height: 6)
                        Text(online ? String(localized: "在线", comment: "Online") : String(localized: "离线", comment: "Offline"))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .textCase(nil)
        }
    }

    // MARK: - Security
    @ViewBuilder
    private var securitySection: some View {
        if appLock.isDeviceSupported {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $appLock.isEnabled) {
                        Text(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                    }
                    .tint(AppColors.accent)

                    if appLock.isEnabled {
                        Text(String(format: String(localized: "后台 8 秒后自动锁定", comment: "Auto-lock after 8s in background"), Int(AppConstants.lockGracePeriod)))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
            } header: {
                labeledHeader(icon: appLock.hasFaceID ? "faceid" : "touchid",
                              title: appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
            }
        }
    }

    // MARK: - Services
    @ViewBuilder
    private var servicesSection: some View {
        let list = creds.allCredentials
        if !list.isEmpty {
            Section {
                ForEach(list) { cred in
                    row(icon: cred.kind.icon,
                        label: cred.name,
                        value: "\(cred.host):\(cred.port)") {
                        editingCred = cred
                        showAddService = true
                    }
                }

                row(icon: "plus.circle.fill",
                    label: OrbixStrings.navAddService,
                    value: "",
                    tint: AppColors.accent) {
                    editingCred = nil
                    showAddService = true
                }
            } header: {
                labeledHeader(icon: "antenna.radiowaves.left.and.right",
                              title: OrbixStrings.sectionServices)
            }
        }
    }

    // MARK: - Update
    @ViewBuilder
    private var updateSection: some View {
        Section {
            HStack {
                Group {
                    if isCheckingUpdate {
                        Label(OrbixStrings.btnCheckUpdate, systemImage: "arrow.down.circle.dotted")
                    } else if let check = updateCheck, check.latest != nil {
                        Label(OrbixStrings.miscUpdateAvailable, systemImage: "star.circle.fill")
                            .foregroundColor(AppColors.warning)
                    } else if updateCheck?.error != nil {
                        Label(OrbixStrings.btnRetry, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(AppColors.danger)
                    } else if updateCheck != nil {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(OrbixStrings.btnCheckUpdate, systemImage: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text(OrbixStrings.msgUpToDate)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.success.opacity(0.8))
                        }
                    } else {
                        Label(OrbixStrings.btnCheckUpdate, systemImage: "arrow.down.circle")
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            .contentShape(Rectangle())
            .onTapGesture { checkUpdate() }
            .disabled(isCheckingUpdate)

            if let release = updateCheck?.latest {
                updateReleaseInfo(release)
            }

            if isDownloading {
                downloadProgressBar
            }
        } header: {
            labeledHeader(icon: "arrow.down.circle", title: "v\(appVersion)")
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        Section {
            row(icon: "tag", label: String(localized: "版本", comment: "Version"), value: appVersion)
            row(icon: "number", label: String(localized: "构建号", comment: "Build"), value: buildNumber)
        } header: {
            labeledHeader(icon: "info.circle", title: String(localized: "关于", comment: "About"))
        }
    }

    // MARK: - Update Release Info
    private func updateReleaseInfo(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text(release.version)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.label)
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryLabel)
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
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: AppRadius.sm).fill(AppColors.accent))
            }
            .disabled(isDownloading)
        }
        .padding(.vertical, 8)
    }

    private var downloadProgressBar: some View {
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

    // MARK: - Row Helpers
    private func labeledHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.label)
        }
        .textCase(nil)
    }

    private func row(icon: String, label: String, value: String, tint: Color = AppColors.label, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(action == nil ? AppColors.tertiaryLabel : tint)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(action == nil ? AppColors.secondaryLabel : tint)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(tint)
                        .lineLimit(1)
                }
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
        }
        .disabled(action == nil)
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
        .preferredColorScheme(.dark)
}
#endif
