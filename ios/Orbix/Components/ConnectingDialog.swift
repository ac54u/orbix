import SwiftUI

struct ConnectingDialog: View {
    let message: String

    @State private var isVisible = false

    var body: some View {
        ZStack {
            AppColors.mainBg.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.accent)

                Text(message)
                    .bodyFont()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColors.card)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
            )
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
}

struct ConnectingDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    var message: String

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ConnectingDialog(message: message)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeOut(duration: 0.25), value: isPresented)
    }
}

extension View {
    func connectingDialog(isPresented: Binding<Bool>, message: String = "连接中...") -> some View {
        modifier(ConnectingDialogModifier(isPresented: isPresented, message: message))
    }
}
