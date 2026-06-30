import SwiftUI

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum AppColors {
    static let groupedBg = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#000000"))
    static let mainBg = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#000000"))
    static let plainBg = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1C1C1E"))
    static let card = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1C1C1E"))
    static let elevated = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#2C2C2E"))

    static let label = Color(light: Color(hex: "#1C1C1E"), dark: Color(hex: "#FFFFFF"))
    static let secondaryLabel = Color(light: Color(hex: "#6E6E73"), dark: Color(hex: "#AEAEB2"))
    static let tertiaryLabel = Color(light: Color(hex: "#AEAEB2"), dark: Color(hex: "#6E6E73"))

    static let separator = Color(light: Color(hex: "#E5E5EA"), dark: Color(hex: "#38383A"))
    static let placeholder = Color(light: Color(hex: "#C7C7CC"), dark: Color(hex: "#545458"))

    static let accent = Color(light: Color(hex: "#3B82F6"), dark: Color(hex: "#60A5FA"))
    static let accentDark = Color(light: Color(hex: "#2563EB"), dark: Color(hex: "#93BBFD"))
    static let accentSoftBg = Color(light: Color(hex: "#EBF0FF"), dark: Color(hex: "#1E293B"))

    static let success = Color(light: Color(hex: "#34C759"), dark: Color(hex: "#30D158"))
    static let warning = Color(light: Color(hex: "#FF9500"), dark: Color(hex: "#FF9F0A"))
    static let danger = Color(light: Color(hex: "#FF3B30"), dark: Color(hex: "#FF453A"))

    static let skeletonBase = Color(light: Color(hex: "#E5E5EA"), dark: Color(hex: "#2C2C2E"))
    static let skeletonHighlight = Color(light: Color(hex: "#D1D1D6"), dark: Color(hex: "#3A3A3C"))

    static let logoGradient = LinearGradient(
        colors: [accent, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassBorder = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
}

enum AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

struct TeslaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.card.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .stroke(AppColors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func teslaCard() -> some View {
        modifier(TeslaCard())
    }
}
