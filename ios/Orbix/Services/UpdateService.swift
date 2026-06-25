import Foundation

actor UpdateService {
    static let shared = UpdateService()
    private init() {}

    private let session = URLSession(configuration: .ephemeral)
    private let repo = "ac54u/orbix"

    func check() async -> UpdateCheck {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        if let lastCheck = PersistenceService.shared.lastUpdateCheckTime,
           Date().timeIntervalSince(lastCheck) < 1800,
           let cachedTag = PersistenceService.shared.cachedUpdateTag {
            return UpdateCheck(
                hasUpdate: cachedTag.compare(currentVersion, options: .numeric) == .orderedDescending,
                currentVersion: currentVersion,
                latest: nil,
                error: nil
            )
        }

        do {
            guard let release = try await fetchLatest() else {
                PersistenceService.shared.lastUpdateCheckTime = Date()
                return .upToDate(currentVersion)
            }

            PersistenceService.shared.lastUpdateCheckTime = Date()
            PersistenceService.shared.cachedUpdateTag = release.tag

            let hasNew = release.tag.compare(currentVersion, options: .numeric) == .orderedDescending
            return hasNew
                ? .available(currentVersion, release: release)
                : .upToDate(currentVersion)
        } catch {
            return .failed(currentVersion, error: error.localizedDescription)
        }
    }

    private func fetchLatest() async throws -> AppRelease? {
        let urlStr = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)

        guard let httpResp = response as? HTTPURLResponse else { return nil }
        if httpResp.statusCode == 404 { return nil }
        guard httpResp.statusCode == 200 else {
            throw UpdateError.fetchFailed("HTTP \(httpResp.statusCode)")
        }

        return try JSONDecoder().decode(AppRelease.self, from: data)
    }

    func downloadIpa(_ release: AppRelease, progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        guard let ipaUrlStr = release.ipaUrl, let ipaUrl = URL(string: ipaUrlStr) else {
            throw UpdateError.noIpaUrl
        }

        let tempDir = FileManager.default.temporaryDirectory
        let destUrl = tempDir.appendingPathComponent("Orbix-\(release.version).ipa")

        var req = URLRequest(url: ipaUrl)
        let (bytes, response) = try await session.bytes(for: req)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }

        let expectedSize = httpResp.expectedContentLength
        var downloaded: Int64 = 0
        var fileData = Data()

        for try await byte in bytes {
            fileData.append(byte)
            downloaded += 1
            if expectedSize > 0 {
                let progress = Double(downloaded) / Double(expectedSize)
                progressHandler?(progress)
            }
        }

        try fileData.write(to: destUrl)
        return destUrl
    }
}

enum UpdateError: LocalizedError {
    case noIpaUrl
    case downloadFailed
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .noIpaUrl: return "No .ipa URL found in release"
        case .downloadFailed: return "Download failed"
        case .fetchFailed(let msg): return msg
        }
    }
}
