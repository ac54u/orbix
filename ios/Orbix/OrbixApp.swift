import SwiftUI

@main
struct OrbixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appLock = AppLockService.shared

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ContentView()
            }
            .environmentObject(appLock)
            .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}
