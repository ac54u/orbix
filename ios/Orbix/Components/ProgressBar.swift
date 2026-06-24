import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 0.5  // hairline: 1 pixel (0.5 pt on 2x display)
    var color: Color = AppColors.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: height)
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

func formatSpeed(_ speed: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    if speed >= gb { return String(format: "%.1f GB/s", Double(speed) / Double(gb)) }
    if speed >= mb { return String(format: "%.1f MB/s", Double(speed) / Double(mb)) }
    if speed >= kb { return String(format: "%.1f KB/s", Double(speed) / Double(kb)) }
    return "\(speed) B/s"
}

func formatBytes(_ bytes: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    let tb = gb * 1024
    if bytes >= tb { return String(format: "%.2f TB", Double(bytes) / Double(tb)) }
    if bytes >= gb { return String(format: "%.2f GB", Double(bytes) / Double(gb)) }
    if bytes >= mb { return String(format: "%.2f MB", Double(bytes) / Double(mb)) }
    if bytes >= kb { return String(format: "%.2f KB", Double(bytes) / Double(kb)) }
    return "\(bytes) B"
}

struct SpeedBadge: View {
    let speed: Int64

    var body: some View {
        Text(formatSpeed(speed))
            .caption(AppColors.tertiaryLabel)
    }
}

struct SizeText: View {
    let bytes: Int64

    var body: some View {
        Text(formatBytes(bytes))
            .subtitle()
    }
}
