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
        let cache = URLCache(memoryCapacity: 100 * 1024 * 1024,
                             diskCapacity: 500 * 1024 * 1024,
                             diskPath: "orbix_image_cache")
        URLCache.shared = cache
        return true
    }
}
