import Foundation

// MARK: - Prowlarr API
enum ProwlarrApi {

    private static let session = URLSession(configuration: .ephemeral)
    private static let decoder = JSONDecoder()

    struct ProwlarrSearchResult: Codable, Identifiable {
        let id: Int
        let title: String
        let indexer: String?
        let size: Int64
        let seeders: Int
        let leechers: Int
        let downloadUrl: String?
        let publishDate: String?

        enum CodingKeys: String, CodingKey {
            case id, title, indexer, size, seeders, leechers
            case downloadUrl = "downloadUrl"
            case publishDate = "publishDate"
        }
    }

    @MainActor
    static func search(query: String, indexerIds: [Int] = []) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else { return [] }
        var urlStr = "\(cred.apiURL)/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=search"
        if !indexerIds.isEmpty {
            urlStr += "&indexerIds=\(indexerIds.map(String.init).joined(separator: ","))"
        }
        guard let url = URL(string: urlStr) else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        let results = (try? decoder.decode([ProwlarrSearchResult].self, from: data)) ?? []
        return results.map(\.toUnified)
    }

    @MainActor
    static func getIndexers() async throws -> [(id: Int, name: String)] {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/indexer") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return json?.compactMap { item in
            guard let id = item["id"] as? Int, let name = item["name"] as? String else { return nil }
            return (id, name)
        } ?? []
    }
}

private extension ProwlarrApi.ProwlarrSearchResult {
    var toUnified: SearchResult {
        SearchResult(
            num: id,
            descr: downloadUrl ?? "",
            fileName: title,
            fileSize: Int(size),
            nbLeechers: leechers,
            nbSeeders: seeders,
            siteUrl: indexer ?? ""
        )
    }
}
