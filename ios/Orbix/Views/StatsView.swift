import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true
    @State private var lastUpdate = Date()
    @State private var refreshSuppressed = false
    @State private var altSpeedEnabled = false
    @State private var history: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var upHistory: [CGFloat] = Array(repeating: 0, count: 30)
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if !isLoading {
                        altSpeedBar
                    }

                    heroSection

                    if transfer?.serverState != nil {
                        SectionHeader(title: OrbixStrings.statsVolume, icon: "arrow.down.arrow.up")
                            .padding(.horizontal, 20)
                        volumeSection

                        SectionHeader(title: OrbixStrings.statsDisk, icon: "externaldrive")
                            .padding(.horizontal, 20)
                        serverSection
                    }

                    SectionHeader(title: OrbixStrings.statsOverview, icon: "square.grid.2x2")
                        .padding(.horizontal, 20)
                    overviewGrid

                    lastUpdateLabel
                        .padding(.top, 8)

                    Color.clear.frame(height: 24)
                }
                .padding(.vertical, 16)
            }
            .background(AppColors.mainBg)
            .navigationTitle(OrbixStrings.navTransferStats)
            .refreshable { await manualRefresh() }
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard !refreshSuppressed else { return }
                refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                refreshSuppressed = newPhase != .active
            }
        }
    }

    // MARK: - Alt Speed Bar
    private var altSpeedBar: some View {
        HStack(spacing: 10) {
            Image(systemName: altSpeedEnabled ? "tortoise.fill" : "hare.fill")
                .font(.system(size: 16))
                .foregroundColor(altSpeedEnabled ? AppColors.warning : AppColors.success)
            Text(altSpeedEnabled ? String(localized: "备用限速已启用", comment: "Alt speed enabled")
                 : String(localized: "全速模式", comment: "Full speed mode"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Button {
                Task {
                    try? await QBitApi.shared.toggleSpeedLimitsMode()
                    await MainActor.run { altSpeedEnabled.toggle() }
                    let f = UINotificationFeedbackGenerator()
                    f.notificationOccurred(.success)
                }
            } label: {
                Text(altSpeedEnabled ? String(localized: "恢复全速", comment: "Restore full speed")
                     : String(localized: "启用来", comment: "Enable alt"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(AppColors.accent.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        let totalSpeed = (transfer?.dlInfoSpeed ?? 0) + (transfer?.upInfoSpeed ?? 0)
        let dlSpeed = CGFloat(transfer?.dlInfoSpeed ?? 0)
        let upSpeed = CGFloat(transfer?.upInfoSpeed ?? 0)
        let maxSpeed: CGFloat = max(dlSpeed + upSpeed, 1)
        let dlRatio = maxSpeed > 0 ? dlSpeed / maxSpeed : 0
        let upRatio = maxSpeed > 0 ? upSpeed / maxSpeed : 0
        let dlLimit = transfer?.dlRateLimit ?? 0
        let upLimit = transfer?.upRateLimit ?? 0

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heroSpeedString(totalSpeed))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.label)
                    Text("B/s")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(AppColors.elevated, lineWidth: 10)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0, to: dlRatio)
                        .stroke(
                            AppColors.accent,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0, to: upRatio)
                        .stroke(
                            AppColors.success,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 86, height: 86)

                    VStack(spacing: 0) {
                        Text("↓")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.accent)
                        Text("\(Int(dlRatio * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider().background(AppColors.separator).padding(.horizontal, 16)

            HStack(spacing: 0) {
                speedLegend(color: AppColors.accent, icon: "arrow.down", label: String(localized: "下载", comment: "Download"),
                            speed: formatSpeed(Int64(dlSpeed)), limit: dlLimit > 0 ? "/\(formatSpeed(dlLimit))" : "")
                Divider().frame(height: 28).background(AppColors.separator)
                speedLegend(color: AppColors.success, icon: "arrow.up", label: String(localized: "上传", comment: "Upload"),
                            speed: formatSpeed(Int64(upSpeed)), limit: upLimit > 0 ? "/\(formatSpeed(upLimit))" : "")
            }
            .padding(.vertical, 10)

            if history.contains(where: { $0 > 0 }) {
                Divider().background(AppColors.separator).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "速度趋势", comment: "Speed trend"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Spacer()
                        Text(String(localized: "30秒", comment: "30 seconds"))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.placeholder)
                    }
                    .padding(.horizontal, 16)

                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let dlMax = history.max() ?? 1
                        let upMax = upHistory.max() ?? 1

                        ZStack(alignment: .bottomLeading) {
                            Path { path in
                                for (i, v) in upHistory.enumerated() {
                                    let x = w * CGFloat(i) / CGFloat(max(upHistory.count - 1, 1))
                                    let y = h * (1 - (v / max(upMax, 1) * 0.6))
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(AppColors.success.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                            Path { path in
                                for (i, v) in history.enumerated() {
                                    let x = w * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                                    let y = h * (1 - (v / max(dlMax, 1) * 0.6))
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .frame(height: 40)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
        .padding(.horizontal, 20)
    }

    private func speedLegend(color: Color, icon: String, label: String, speed: String, limit: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
            Text(speed)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.label)
            if !limit.isEmpty {
                Text(limit)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Volume Section
    private var volumeSection: some View {
        let dlData = transfer?.dlInfoData ?? 0
        let upData = transfer?.upInfoData ?? 0
        let totalData = dlData + upData
        let dlDataRatio = totalData > 0 ? CGFloat(dlData) / CGFloat(totalData) : 0.5

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(OrbixStrings.statsSessionDL)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                    Text(formatBytes(dlData))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(OrbixStrings.statsSessionUL)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryLabel)
                    Text(formatBytes(upData))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.success)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            GeometryReader { geo in
                let barW = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.elevated)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.accent)
                        .frame(width: barW * dlDataRatio, height: 8)
                }
                .animation(.easeInOut(duration: 0.6), value: dlDataRatio)
            }
            .frame(height: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            if let state = transfer?.serverState {
                Divider().background(AppColors.separator).padding(.horizontal, 16)

                HStack(spacing: 0) {
                    compactStat(OrbixStrings.statsTotalDL, formatBytes(state.alltimeDl), AppColors.accent)
                    compactStat(OrbixStrings.statsTotalUL, formatBytes(state.alltimeUl), AppColors.success)
                    compactStat(OrbixStrings.statsGlobalRatio, state.globalRatio ?? "—", AppColors.warning)
                }
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
        .padding(.horizontal, 20)
    }

    private func compactStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(AppColors.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Server Section
    private var serverSection: some View {
        VStack(spacing: 12) {
            if let state = transfer?.serverState {
                connectionBar(status: state.connectionStatus)

                Divider().background(AppColors.separator)

                diskBar(free: state.freeSpaceOnDisk)

                Divider().background(AppColors.separator)

                HStack(spacing: 12) {
                    chip(icon: "network", label: "DHT", value: "\(state.dhtNodes)")
                    if state.queueing {
                        chip(icon: "hourglass", label: String(localized: "排队中", comment: "Queueing"), value: "")
                            .foregroundColor(AppColors.warning)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.card)
        )
        .padding(.horizontal, 20)
    }

    private func connectionBar(status: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(connectionColor(status))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(connectionColor(status))
                        .frame(width: 10, height: 10)
                        .opacity(0.4)
                        .scaleEffect(connectionColor(status) == AppColors.success ? 1.3 : 1.0)
                        .animation(
                            connectionColor(status) == AppColors.success
                                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                : .default,
                            value: connectionColor(status)
                        )
                )
            Text("\(OrbixStrings.statsStatus):")
                .font(.system(size: 13))
                .foregroundColor(AppColors.tertiaryLabel)
            Text(status.capitalized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(connectionColor(status))
            Spacer()
        }
    }

    private func diskBar(free: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(OrbixStrings.statsFreeSpace)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.tertiaryLabel)
                Spacer()
                Text(formatBytes(free))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.success)
                Text(String(localized: "剩余", comment: "free"))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.placeholder)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.elevated)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.success, AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.65, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func chip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 12, weight: .medium))
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
        }
        .foregroundColor(AppColors.secondaryLabel)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(AppColors.elevated)
        )
    }

    // MARK: - Overview Grid
    private var overviewGrid: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let checking = torrents.filter { $0.statusBadge == .checkingDL || $0.statusBadge == .checkingUP }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count
        let completed = torrents.filter { $0.isCompleted && !$0.statusBadge.isUploadRelated }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            overviewTile(icon: "square.stack.fill", label: OrbixStrings.statsTotal, count: torrents.count, color: AppColors.label)
            overviewTile(icon: "arrow.down.circle.fill", label: OrbixStrings.statsDownloading, count: dl, color: AppColors.accent)
            overviewTile(icon: "arrow.up.circle.fill", label: OrbixStrings.statsSeeding, count: up, color: AppColors.success)
            overviewTile(icon: "checkmark.circle.fill", label: String(localized: "已完成", comment: "Completed"), count: completed, color: AppColors.accentDark)
            overviewTile(icon: "pause.circle.fill", label: OrbixStrings.statsPaused, count: paused, color: AppColors.tertiaryLabel)
            overviewTile(icon: "exclamationmark.triangle.fill", label: OrbixStrings.statsError, count: errored, color: AppColors.danger)
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: torrents.count)
    }

    private func overviewTile(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.label)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Last Update
    private var lastUpdateLabel: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.placeholder)
                Text(String(localized: "上次更新：刚才", comment: "Updated just now"))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.placeholder)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Data
    private func heroSpeedString(_ total: Int64) -> String {
        if total >= 1_000_000 { return String(format: "%.1fM", Double(total) / 1_000_000) }
        if total >= 1_000 { return String(format: "%.1fK", Double(total) / 1_000) }
        return "\(total)"
    }

    private func connectionColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "connected": return AppColors.success
        case "firewalled": return AppColors.warning
        default: return AppColors.danger
        }
    }

    private func refresh() {
        Task {
            do {
                let t = try await QBitApi.shared.getTransferInfo()
                let list = try await QBitApi.shared.getTorrents()
                await MainActor.run {
                    transfer = t
                    torrents = list
                    let dlVal = CGFloat(t?.dlInfoSpeed ?? 0) / 1_000_000.0
                    let upVal = CGFloat(t?.upInfoSpeed ?? 0) / 1_000_000.0
                    history.removeFirst()
                    history.append(dlVal)
                    upHistory.removeFirst()
                    upHistory.append(upVal)
                    altSpeedEnabled = t?.serverState?.useAltSpeedLimits ?? altSpeedEnabled
                    isLoading = false
                    lastUpdate = Date()
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    @Sendable private func manualRefresh() async {
        do {
            let t = try await QBitApi.shared.getTransferInfo()
            let list = try await QBitApi.shared.getTorrents()
            await MainActor.run {
                transfer = t; torrents = list; lastUpdate = Date()
                let dlVal = CGFloat(t?.dlInfoSpeed ?? 0) / 1_000_000.0
                let upVal = CGFloat(t?.upInfoSpeed ?? 0) / 1_000_000.0
                history.removeFirst(); history.append(dlVal)
                upHistory.removeFirst(); upHistory.append(upVal)
                altSpeedEnabled = t?.serverState?.useAltSpeedLimits ?? altSpeedEnabled
            }
        } catch {}
    }
}

#if DEBUG
#Preview {
    StatsView()
        .preferredColorScheme(.dark)
}
#endif
