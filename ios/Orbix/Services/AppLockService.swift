import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    @Published var isLocked: Bool
    @Published var isEnabled: Bool {
        didSet {
            PersistenceService.shared.appLockEnabled = isEnabled
        }
    }

    private var enteredBackgroundAt: Date?

    var isDeviceSupported: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var hasFaceID: Bool {
        LAContext().biometryType == .faceID
    }

    private init() {
        let enabled = PersistenceService.shared.appLockEnabled
        isEnabled = enabled
        isLocked = enabled
        observeLifecycle()
    }

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func didEnterBackground() {
        guard isEnabled else { return }
        enteredBackgroundAt = Date()
    }

    @objc private func willEnterForeground() {
        guard isEnabled else { return }

        if let entered = enteredBackgroundAt, Date().timeIntervalSince(entered) > 8 {
            isLocked = true
            authenticate()
        }
        enteredBackgroundAt = nil
    }

    func authenticate(reason: String = OrbixStrings.lockUnlockReason) {
        guard isEnabled else {
            isLocked = false
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = OrbixStrings.lockFallbackTitle

        Task { @MainActor in
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                if success {
                    isLocked = false
                }
            } catch {
                isLocked = true
            }
        }
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct AppLockGate<Content: View>: View {
    @EnvironmentObject private var appLock: AppLockService
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
            if appLock.isLocked {
                LockScreen()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appLock.isLocked)
    }
}

private struct LockScreen: View {
    @EnvironmentObject private var appLock: AppLockService

    private var biometricIcon: String {
        appLock.hasFaceID ? "faceid" : "touchid"
    }

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Button {
                    appLock.authenticate()
                } label: {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(ScaleButtonStyle())

                Text(String(localized: "轻点以验证身份", comment: "Tap to verify identity"))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
    }
}
