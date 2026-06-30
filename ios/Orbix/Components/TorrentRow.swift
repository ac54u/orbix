import SwiftUI

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                StatusIcon(status: torrent.statusBadge)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    nameRow

                    metadataRow

                    progressRow

                    if torrent.dlspeed > 0 || torrent.upspeed > 0 {
                        speedRow
                    }

                    timeRow
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
    }

    private var nameRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(torrent.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.label)
                .lineLimit(2)

            Spacer(minLength: AppSpacing.xs)

            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text(formatBytes(torrent.size))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.secondaryLabel)

                if torrent.ratio > 0 {
                    ratioBadge
                }
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: AppSpacing.sm) {
            if !torrent.category.isEmpty {
                categoryPill
            }

            statusBadge

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.tertiaryLabel)
                Text("\(torrent.numSeeds)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.secondaryLabel)
            }

            if torrent.numLeechs > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "person.2")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                    Text("\(torrent.numLeechs)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }

            if torrent.statusBadge == .downloading, torrent.eta > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.tertiaryLabel)
                    Text(torrent.etaFormatted)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
    }

    private var progressRow: some View {
        HStack(spacing: AppSpacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(AppColors.separator.opacity(0.4))

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(torrent.progressColor)
                        .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                        .animation(.linear(duration: 0.3), value: torrent.progress)
                }
            }
            .frame(height: 2.5)

            Text("\(torrent.progressPercent)%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(torrent.isCompleted ? AppColors.success : AppColors.tertiaryLabel)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var speedRow: some View {
        HStack(spacing: AppSpacing.md) {
            if torrent.dlspeed > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text(formatSpeed(torrent.dlspeed))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                }
            }

            if torrent.upspeed > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.success)
                    Text(formatSpeed(torrent.upspeed))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.success)
                }
            }
        }
    }

    @ViewBuilder
    private var timeRow: some View {
        let addedInfo = relativeTime(from: torrent.addedOn)
        let completedInfo: String? = {
            guard torrent.isCompleted || torrent.completionOn > 0 else { return nil }
            return relativeTime(from: torrent.completionOn)
        }()

        if let completed = completedInfo {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.success)
                Text("\(String(localized: "完成于", comment: "Completed at")) \(completed)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        } else if !addedInfo.isEmpty {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.placeholder)
                Text("\(String(localized: "添加于", comment: "Added at")) \(addedInfo)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.placeholder)
            }
        }
    }

    private var categoryPill: some View {
        Text(torrent.category)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(AppColors.accentSoftBg)
            )
    }

    private var ratioBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: torrent.ratio >= 1.0 ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 9, weight: .medium))
            Text(String(format: "%.2f", torrent.ratio))
                .font(.system(size: 12, design: .monospaced))
        }
        .foregroundColor(torrent.ratio >= 1.0 ? AppColors.success : AppColors.warning)
    }

    private var statusBadge: some View {
        Text(torrent.statusBadge.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(torrent.statusBadge.statusColor)
    }
}

#if DEBUG
#Preview {
    let now = Int64(Date().timeIntervalSince1970)
    VStack(spacing: AppSpacing.sm) {
        TorrentRow(torrent: .demo(addedOn: now - 3600))
        TorrentRow(torrent: .demo(
            name: "Debian 12.5.0 amd64 netinst.iso",
            state: "uploading",
            progress: 1.0,
            dlspeed: 0,
            upspeed: 5_120_000,
            size: 629_145_600,
            ratio: 3.42,
            numSeeds: 0,
            numLeechs: 0,
            addedOn: now - 259200,
            completionOn: now - 86400
        ))
        TorrentRow(torrent: .demo(
            name: "Fedora-Workstation-Live-x86_64-40.iso",
            state: "pausedDL",
            progress: 0.32,
            dlspeed: 0,
            upspeed: 0,
            size: 2_147_483_648,
            numSeeds: 85,
            numLeechs: 12,
            addedOn: now - 604800
        ))
    }
    .padding(.horizontal, AppSpacing.lg)
    .padding(.vertical, AppSpacing.md)
    .background(AppColors.mainBg)
}
#endif
