// MARK: - Deprecated: use native List + .swipeActions instead

import SwiftUI

struct SwipeableTorrentCard: View {
    let torrent: TorrentInfo
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var navigateToDetail = false
    @State private var isDragging = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                if offset < 0 {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.danger)
                        .frame(width: 72)
                        .padding(.vertical, 4)
                        .overlay(alignment: .trailing) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.label)
                                .padding(.trailing, 16)
                                .scaleEffect(offset < -50 ? 1.2 : 0.9)
                                .opacity(offset < -20 ? 1 : 0)
                                .animation(AppMotion.fastAnim(), value: offset)
                        }
                        .onTapGesture {
                            autoDismissTask?.cancel()
                            guard !isDeleting else { return }
                            isDeleting = true
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            withAnimation(AppMotion.mediumAnim()) {
                                offset = -geometry.size.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDelete()
                            }
                        }
                }

                Button {
                    autoDismissTask?.cancel()
                    guard !isDragging else { return }
                    if offset < 0 {
                        withAnimation(AppMotion.mediumAnim()) {
                            offset = 0
                        }
                    } else {
                        navigateToDetail = true
                    }
                } label: {
                    TorrentRow(torrent: torrent)
                }
                .buttonStyle(SolidCardButtonStyle())
                .accessibilityLabel("\(torrent.name), \(torrent.statusBadge.displayName), \(torrent.progressPercent)%")
                .accessibilityHint(String(localized: "轻点查看详情，向左滑动删除", comment: "Tap to view details, swipe left to delete"))
                .offset(x: offset)
                .navigationDestination(isPresented: $navigateToDetail) {
                    TorrentDetailView(hash: torrent.hash)
                }
            }
            .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isDeleting else { return }
                    isDragging = true
                    if value.translation.width < 0 && abs(value.translation.width) > abs(value.translation.height) {
                        offset = value.translation.width * 0.8
                    }
                }
                .onEnded { value in
                    guard !isDeleting else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        offset = 0
                        isDragging = false
                        return
                    }
                    withAnimation(AppMotion.mediumAnim()) {
                        if value.translation.width < -50 {
                            offset = -72
                        } else {
                            offset = 0
                        }
                    }
                    DispatchQueue.main.async {
                        isDragging = false
                    }
                }
        )
            .onChange(of: offset) { _, newValue in
                autoDismissTask?.cancel()
                guard newValue < 0, !isDeleting else { return }
                autoDismissTask = Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    guard !Task.isCancelled, !isDeleting else { return }
                    await MainActor.run {
                        withAnimation(AppMotion.mediumAnim()) {
                            offset = 0
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    SwipeableTorrentCard(torrent: .demo(), onDelete: {})
        .padding(.horizontal, 16)
}
#endif
