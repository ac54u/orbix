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
        let magnetUrl: String?
        let publishDate: String?

        enum CodingKeys: String, CodingKey {
            case guid, title, indexer, size, seeders, leechers
            case downloadUrl, magnetUrl, publishDate
        }
    }

    @MainActor
    static func search(query: String) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard var components = URLComponents(string: "\(cred.apiURL)/search") else {
            throw ApiError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = components.url else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Prowlarr", code: http.statusCode)
        }
        let results = try decoder.decode([ProwlarrSearchResult].self, from: data)
        return results.map(\.toUnified)
    }

    @MainActor
    static func searchMovie(tmdbId: Int) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard var components = URLComponents(string: "\(cred.apiURL)/search") else {
            throw ApiError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: "tmdb:\(tmdbId)"),
            URLQueryItem(name: "type", value: "movie")
        ]
        guard let url = components.url else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Prowlarr", code: http.statusCode)
        }
        let results = try decoder.decode([ProwlarrSearchResult].self, from: data)
        return results.map(\.toUnified)
    }

    @MainActor
    static func downloadTorrent(url: String) async throws -> Data {
        guard let cred = CredentialsManager.shared.prowlarr, !cred.apiKey.isEmpty else {
            throw ApiError.unauthorized
        }
        guard let torrentURL = URL(string: url) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: torrentURL)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Prowlarr", code: http.statusCode)
        }
        return data
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
    private var stableId: Int {
        var h: Int = 5381
        for byte in guid.utf8 {
            h = ((h << 5) &+ h) &+ Int(byte)
        }
        return abs(h)
    }

    var toUnified: SearchResult {
        let downloadLink = magnetUrl ?? downloadUrl ?? ""
        return SearchResult(
            num: stableId,
            descr: downloadLink,
            fileName: title,
            fileSize: Int(size),
            nbLeechers: leechers,
            nbSeeders: seeders,
            siteUrl: indexer ?? ""
        )
    }
}
