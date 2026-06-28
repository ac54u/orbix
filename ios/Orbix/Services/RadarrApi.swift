import Foundation

// MARK: - Radarr API
enum RadarrApi {

    private static let session = URLSession(configuration: .ephemeral)
    private static let decoder = JSONDecoder()

    struct RadarrMovie: Codable, Identifiable {
        let id: Int
        let title: String
        let year: Int?
        let overview: String?
        let tmdbId: Int?
        let images: [RadarrImage]?
        let hasFile: Bool?

        enum CodingKeys: String, CodingKey {
            case id, title, year, overview, images, hasFile
            case tmdbId = "tmdbId"
        }
    }

    struct RadarrImage: Codable {
        let coverType: String
        let remoteUrl: String?

        enum CodingKeys: String, CodingKey {
            case coverType, remoteUrl
        }
    }

    struct QualityProfile: Codable, Identifiable {
        let id: Int
        let name: String
    }

    struct RootFolder: Codable, Identifiable {
        let id: Int
        let path: String
        let freeSpace: Int64?

        enum CodingKeys: String, CodingKey {
            case id, path, freeSpace
        }
    }

    // MARK: - Lookup

    @MainActor
    static func lookup(query: String) async throws -> [SearchResult] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        let urlStr = "\(cred.apiURL)/movie/lookup?term=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        guard let url = URL(string: urlStr) else { return [] }

        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        let movies = (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
        return movies.map { movie in
            SearchResult(
                num: movie.tmdbId ?? movie.id,
                descr: "",
                fileName: movie.title + (movie.year.map { " (\($0))" } ?? ""),
                fileSize: 0,
                nbLeechers: 0,
                nbSeeders: 0,
                siteUrl: movie.images?.first(where: { $0.coverType == "poster" })?.remoteUrl ?? "",
                isAdded: movie.id > 0 || movie.hasFile == true
            )
        }
    }

    @MainActor
    static func getMovies() async throws -> [RadarrMovie] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/movie") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        return (try? decoder.decode([RadarrMovie].self, from: data)) ?? []
    }

    // MARK: - Profiles & Root Folders
    @MainActor
    static func getQualityProfiles() async throws -> [QualityProfile] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/qualityprofile") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        return (try? decoder.decode([QualityProfile].self, from: data)) ?? []
    }

    @MainActor
    static func getRootFolders() async throws -> [RootFolder] {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return [] }
        guard let url = URL(string: "\(cred.apiURL)/rootfolder") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: req)
        return (try? decoder.decode([RootFolder].self, from: data)) ?? []
    }

    // MARK: - Add Movie
    @MainActor
    static func addMovie(
        tmdbId: Int,
        title: String,
        year: Int,
        qualityProfileId: Int,
        rootFolderPath: String,
        monitored: Bool = true,
        searchOnAdd: Bool = true
    ) async throws {
        guard let cred = CredentialsManager.shared.radarr, !cred.apiKey.isEmpty else { return }
        guard let url = URL(string: "\(cred.apiURL)/movie") else { return }

        let body: [String: Any] = [
            "tmdbId": tmdbId,
            "title": title,
            "year": year,
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "monitored": monitored,
            "addOptions": ["searchForMovie": searchOnAdd]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(cred.apiKey, forHTTPHeaderField: "X-Api-Key")
        req.httpBody = jsonData
        let _ = try await session.data(for: req)
    }
}
