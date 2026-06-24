import SwiftUI

struct SkeletonBar: View {
    var height: CGFloat = 12
    var width: CGFloat? = nil

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(isAnimating ? AppColors.skeletonHighlight : AppColors.skeletonBase)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .animation(
                .easeInOut(duration: AppMotion.skeletonCycle)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
