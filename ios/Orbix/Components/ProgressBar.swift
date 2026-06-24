import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 2
    var color: Color = AppColors.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppColors.separator)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: height)
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

struct SpeedBadge: View {
    let speed: Int64

    var body: some View {
        Text(formattedSpeed)
            .caption(AppColors.tertiaryLabel)
    }

    private var formattedSpeed: String {
        if speed >= 1_000_000_000 {
            String(format: "%.1f GB/s", Double(speed) / 1_000_000_000)
        } else if speed >= 1_000_000 {
            String(format: "%.1f MB/s", Double(speed) / 1_000_000)
        } else if speed >= 1_000 {
            String(format: "%.1f KB/s", Double(speed) / 1_000)
        } else {
            "\(speed) B/s"
        }
    }
}

struct SizeText: View {
    let bytes: Int64

    var body: some View {
        Text(formattedSize)
            .subtitle()
    }

    private var formattedSize: String {
        if bytes >= 1_000_000_000_000 {
            String(format: "%.2f TB", Double(bytes) / 1_000_000_000_000)
        } else if bytes >= 1_000_000_000 {
            String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            String(format: "%.2f MB", Double(bytes) / 1_000_000)
        } else if bytes >= 1_000 {
            String(format: "%.2f KB", Double(bytes) / 1_000)
        } else {
            "\(bytes) B"
        }
    }
}
