import SwiftUI

struct GlowingLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.logoGradient)
                .frame(width: size, height: size)
                .shadow(color: AppColors.accent.opacity(0.4), radius: size * 0.25, x: 0, y: 4)

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
