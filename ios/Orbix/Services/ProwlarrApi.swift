import Foundation

// MARK: - Prowlarr API
enum ProwlarrApi {

    private static let session = URLSession(configuration: .ephemeral)
    private static let decoder = JSONDecoder()

    struct ProwlarrSearchResult: Codable, Identifiable {
        let guid: String
        var id: String { guid }
        let title: String
        let indexer: String?
        let size: Int64
        let seeders: Int
        let leechers: Int
        let downloadUrl: String?
        let publishDate: String?

        enum CodingKeys: String, CodingKey {
            case guid, title, indexer, size, seeders, leechers
            case downloadUrl, publishDate
        }
    }

    @MainActor
    static func search(query: String, indexerIds: [Int] = []) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else { return [] }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        guard let url = URL(string: "\(cred.apiURL)/search?query=\(encoded)&type=search") else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        // Throw on non-200 so caller can show error
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Prowlarr", code: http.statusCode)
        }
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
            num: guid.hashValue,
            descr: downloadUrl ?? "",
            fileName: title,
            fileSize: Int(size),
            nbLeechers: leechers,
            nbSeeders: seeders,
            siteUrl: indexer ?? ""
        )
    }
}
