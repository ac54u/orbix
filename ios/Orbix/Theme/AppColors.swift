import SwiftUI

enum AppColors {
    // Backgrounds
    static let groupedBg = Color(hex: "#161718")
    static let mainBg = Color(hex: "#161718")
    static let plainBg = Color(hex: "#161718")
    static let card = Color(hex: "#1E1F20")
    static let elevated = Color(hex: "#282829")

    // Text
    static let label = Color(hex: "#FAFAFA")
    static let secondaryLabel = Color(hex: "#909191")
    static let tertiaryLabel = Color(hex: "#6B6C6D")

    // UI
    static let separator = Color(hex: "#2E2E2F")
    static let placeholder = Color(hex: "#4A4B4C")

    // Accent
    static let accent = Color(hex: "#366EF6")
    static let accentDark = Color(hex: "#0E52BA")
    static let accentSoftBg = Color(hex: "#1C2438")

    // Status
    static let success = Color(hex: "#03B661")
    static let warning = Color(hex: "#E6A23C")
    static let danger = Color(hex: "#FF5255")

    // Skeleton
    static let skeletonBase = Color(hex: "#242526")
    static let skeletonHighlight = Color(hex: "#2E2F30")

    // Gradient
    static let logoGradient = LinearGradient(
        colors: [accent, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
