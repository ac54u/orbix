import SwiftUI

struct SectionHeader: View {
    let title: String
    var icon: String?

    init(title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
        }
        .padding(.leading, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    SectionHeader(title: "示例标题")
}
#endif
