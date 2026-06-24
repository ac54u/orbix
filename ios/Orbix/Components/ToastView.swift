import SwiftUI

enum ToastType {
    case neutral
    case success
    case error

    var color: Color {
        switch self {
        case .neutral: return AppColors.elevated
        case .success: return AppColors.success
        case .error: return AppColors.danger
        }
    }
}

struct ToastView: View {
    let type: ToastType
    let message: String

    @State private var isShowing = false

    var body: some View {
        Text(message)
            .bodyFont(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(type.color)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .opacity(isShowing ? 1 : 0)
            .scaleEffect(isShowing ? 1 : 0.85)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isShowing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
            }
    }
}

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private init() {}

    @Published var isShowing = false
    @Published var message = ""
    @Published var type: ToastType = .neutral

    private var task: Task<Void, Never>?

    func show(_ message: String, type: ToastType = .neutral) {
        task?.cancel()
        self.message = message
        self.type = type
        isShowing = true

        task = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled {
                isShowing = false
            }
        }
    }
}
