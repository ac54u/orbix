import SwiftUI

enum AppTypography {
    static func hero(_ color: Color = AppColors.label) -> Font {
        .system(size: 56, weight: .ultraLight, design: .default)
            .monospacedDigit()
    }

    static func navTitle(_ color: Color = AppColors.label) -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func largeTitle(_ color: Color = AppColors.label) -> Font {
        .system(size: 34, weight: .bold)
            .leading(.tight)
    }

    static func cardTitle(_ color: Color = AppColors.label) -> Font {
        .system(size: 22, weight: .bold)
    }

    static func sectionHeader(_ color: Color = AppColors.secondaryLabel) -> Font {
        .system(size: 13, weight: .regular)
    }

    static func body(_ color: Color = AppColors.label) -> Font {
        .system(size: 17, weight: .regular)
    }

    static func subtitle(_ color: Color = AppColors.secondaryLabel) -> Font {
        .system(size: 15, weight: .regular)
    }

    static func caption(_ color: Color = AppColors.tertiaryLabel) -> Font {
        .system(size: 12, weight: .medium)
    }
}

extension Font {
    func leading(_ style: LeadingStyle) -> Font {
        self.leading(style)
    }
}

enum LeadingStyle {
    case tight
    case standard
    case loose
}

extension View {
    func hero(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.hero(color))
    }
    func navTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.navTitle(color))
    }
    func largeTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.largeTitle(color))
    }
    func cardTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.cardTitle(color))
    }
    func sectionHeader(_ color: Color = AppColors.secondaryLabel) -> some View {
        self.font(AppTypography.sectionHeader(color))
    }
    func bodyFont(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.body(color))
    }
    func subtitle(_ color: Color = AppColors.secondaryLabel) -> some View {
        self.font(AppTypography.subtitle(color))
    }
    func caption(_ color: Color = AppColors.tertiaryLabel) -> some View {
        self.font(AppTypography.caption(color))
    }
}
