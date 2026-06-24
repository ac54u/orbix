import Foundation

final class PersistenceService {
    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Bookmarks
    func loadBookmarks() -> [String] {
        defaults.stringArray(forKey: "search_bookmarks") ?? []
    }

    func saveBookmarks(_ bookmarks: [String]) {
        defaults.set(bookmarks, forKey: "search_bookmarks")
    }

    func toggleBookmark(_ code: String) -> Bool {
        var bookmarks = loadBookmarks()
        if bookmarks.contains(code) {
            bookmarks.removeAll { $0 == code }
            saveBookmarks(bookmarks)
            return false
        } else {
            bookmarks.append(code)
            saveBookmarks(bookmarks)
            return true
        }
    }

    func isBookmarked(_ code: String) -> Bool {
        loadBookmarks().contains(code)
    }

    // MARK: - Update Cache
    var lastUpdateCheckTime: Date? {
        get { defaults.object(forKey: "last_update_check") as? Date }
        set { defaults.set(newValue, forKey: "last_update_check") }
    }

    var cachedUpdateTag: String? {
        get { defaults.string(forKey: "cached_update_tag") }
        set { defaults.set(newValue, forKey: "cached_update_tag") }
    }

    // MARK: - App Lock
    var appLockEnabled: Bool {
        get { defaults.bool(forKey: "app_lock_face_id") }
        set { defaults.set(newValue, forKey: "app_lock_face_id") }
    }
}
