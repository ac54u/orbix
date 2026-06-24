import Foundation

actor QBitApi {
    static let shared = QBitApi()
    private init() {}

    // MARK: - State
    private var activeServer: ServerConfig?
    private var sessionCookie: String?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    private let decoder = JSONDecoder()

    // MARK: - Server Management
    func loadSavedConfig() -> ServerConfig? {
        guard let host = UserDefaults.standard.string(forKey: "qbit_host") else { return nil }
        return ServerConfig(
            name: UserDefaults.standard.string(forKey: "qbit_name") ?? host,
            host: host,
            port: UserDefaults.standard.integer(forKey: "qbit_port"),
            username: UserDefaults.standard.string(forKey: "qbit_username") ?? "",
            password: UserDefaults.standard.string(forKey: "qbit_password") ?? "",
            https: UserDefaults.standard.bool(forKey: "qbit_https")
        )
    }
    func setActiveServer(_ config: ServerConfig) {
        activeServer = config
        UserDefaults.standard.set(config.name, forKey: "qbit_name")
        UserDefaults.standard.set(config.host, forKey: "qbit_host")
        UserDefaults.standard.set(config.port, forKey: "qbit_port")
        UserDefaults.standard.set(config.username, forKey: "qbit_username")
        UserDefaults.standard.set(config.password, forKey: "qbit_password")
        UserDefaults.standard.set(config.https, forKey: "qbit_https")
    }

    func loadServers() -> [ServerConfig] {
        guard let data = UserDefaults.standard.data(forKey: "qbit_servers"),
              let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) else {
            if let legacy = legacyServerConfig() {
                return [legacy]
            }
            return []
        }
        return servers
    }

    func upsertServer(_ server: ServerConfig) {
        var servers = loadServers()
        if let idx = servers.firstIndex(of: server) {
            servers[idx] = server
        } else {
            servers.append(server)
        }
        saveServers(servers)
    }

    func removeServer(_ server: ServerConfig) {
        var servers = loadServers()
        servers.removeAll { $0 == server }
        saveServers(servers)
    }

    private func saveServers(_ servers: [ServerConfig]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: "qbit_servers")
    }

    private func legacyServerConfig() -> ServerConfig? {
        guard let host = UserDefaults.standard.string(forKey: "qbit_host"),
              let username = UserDefaults.standard.string(forKey: "qbit_username") else { return nil }
        return ServerConfig(
            name: UserDefaults.standard.string(forKey: "qbit_name") ?? "Default",
            host: host,
            port: UserDefaults.standard.integer(forKey: "qbit_port"),
            username: username,
            password: UserDefaults.standard.string(forKey: "qbit_password") ?? "",
            https: UserDefaults.standard.bool(forKey: "qbit_https")
        )
    }

    // MARK: - URL Building
    static func buildUrl(host: String, port: Int, https: Bool) -> String {
        let scheme = https ? "https" : "http"
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return host
        }
        return "\(scheme)://\(host):\(port)"
    }

    private func apiUrl(_ path: String) -> URL? {
        guard let server = activeServer else { return nil }
        let base = Self.buildUrl(host: server.host, port: server.port, https: server.https)
        return URL(string: "\(base)\(path)")
    }

    // MARK: - Auth
    func connect() async -> ConnectResult {
        guard let server = activeServer else {
            return ConnectResult(status: .unknown, message: "No server configured")
        }
        return await login(server: server)
    }

    private func login(server: ServerConfig) async -> ConnectResult {
        sessionCookie = nil
        guard let url = URL(string: "\(server.url)/api/v2/auth/login") else {
            return ConnectResult(status: .unknown, message: "Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(server.url, forHTTPHeaderField: "Origin")
        req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")

        let body = "username=\(server.username)&password=\(server.password)"
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: req)
            guard let httpResp = response as? HTTPURLResponse else {
                return ConnectResult(status: .unknown, message: "Invalid response")
            }

            if httpResp.statusCode == 200 {
                if let setCookie = httpResp.value(forHTTPHeaderField: "Set-Cookie"),
                   let sid = setCookie.split(separator: ";").first {
                    sessionCookie = String(sid)
                } else {
                    sessionCookie = nil
                }
                return .ok
            } else if httpResp.statusCode == 403 {
                return .authFailed
            } else {
                return ConnectResult(status: .network, message: "HTTP \(httpResp.statusCode)")
            }
        } catch {
            return .networkError
        }
    }

    // MARK: - Authenticated Request
    private func authedGet<T: Decodable>(_ path: String, type: T.Type) async throws -> T? {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        req.timeoutInterval = 3

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return try? decoder.decode(T.self, from: data)
    }

    private func authedGetData(_ path: String) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        req.timeoutInterval = 3

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    private func authedPost(_ path: String, body: [String: String]) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = 3

        let bodyStr = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        req.httpBody = bodyStr.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    private func authedPostData(_ path: String, multipartData: Data, boundary: String) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = 30
        req.httpBody = multipartData

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    private func checkAuth(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 || http.statusCode == 403 {
            Task { await renewSession() }
            throw ApiError.unauthorized
        }
    }

    private func renewSession() async {
        guard let server = activeServer else { return }
        let _ = await login(server: server)
    }

    // MARK: - Torrent API
    func getTorrents() async throws -> [TorrentInfo] {
        let data = try await authedGetData("/api/v2/torrents/info")
        return (try? decoder.decode([TorrentInfo].self, from: data)) ?? []
    }

    func syncMainData(rid: Int = 0) async throws -> SyncMainData? {
        try await authedGet("/api/v2/sync/maindata?rid=\(rid)", type: SyncMainData.self)
    }

    func getTransferInfo() async throws -> TransferInfo? {
        try await authedGet("/api/v2/transfer/info", type: TransferInfo.self)
    }

    func getAppVersion() async throws -> String? {
        let data = try await authedGetData("/api/v2/app/version")
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTorrentByHash(_ hash: String) async throws -> TorrentInfo? {
        let data = try await authedGetData("/api/v2/torrents/info?hashes=\(hash)")
        let list = try? decoder.decode([TorrentInfo].self, from: data)
        return list?.first
    }

    func getProperties(_ hash: String) async throws -> TorrentProperties? {
        try await authedGet("/api/v2/torrents/properties?hash=\(hash)", type: TorrentProperties.self)
    }

    func getTorrentFiles(_ hash: String) async throws -> [TorrentFile] {
        let data = try await authedGetData("/api/v2/torrents/files?hash=\(hash)")
        return (try? decoder.decode([TorrentFile].self, from: data)) ?? []
    }

    // MARK: - Torrent Actions
    func startTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/start", body: ["hashes": hash])
    }

    func stopTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/stop", body: ["hashes": hash])
    }

    func forceStartTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/setForceStart", body: ["hashes": hash, "value": "true"])
    }

    func recheckTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/recheck", body: ["hashes": hash])
    }

    func reannounceTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/reannounce", body: ["hashes": hash])
    }

    func deleteTorrent(_ hash: String, deleteFiles: Bool) async throws {
        let _ = try await authedPost("/api/v2/torrents/delete", body: [
            "hashes": hash,
            "deleteFiles": deleteFiles ? "true" : "false"
        ])
    }

    // MARK: - Add Torrent
    func addMagnet(_ urls: [String], category: String? = nil, tags: String? = nil, savePath: String? = nil) async throws -> String? {
        guard let url = apiUrl("/api/v2/torrents/add") else { throw ApiError.invalidURL }

        var body: [String: String] = ["urls": urls.joined(separator: "\n")]
        if let category = category, !category.isEmpty { body["category"] = category }
        if let tags = tags, !tags.isEmpty { body["tags"] = tags }
        if let savePath = savePath, !savePath.isEmpty { body["savepath"] = savePath }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = 30

        let bodyStr = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        req.httpBody = bodyStr.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return String(data: data, encoding: .utf8)
    }

    func addTorrent(bytes: Data, filename: String, category: String? = nil, tags: String? = nil, savePath: String? = nil) async throws -> String? {
        let path = "/api/v2/torrents/add"

        let boundary = "Boundary-\(UUID().uuidString)"
        var multipartData = Data()

        multipartData.append("--\(boundary)\r\n".data(using: .utf8)!)
        multipartData.append("Content-Disposition: form-data; name=\"torrents\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        multipartData.append("Content-Type: application/x-bittorrent\r\n\r\n".data(using: .utf8)!)
        multipartData.append(bytes)
        multipartData.append("\r\n".data(using: .utf8)!)

        if let category = category, !category.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "category", value: category)
        }
        if let tags = tags, !tags.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "tags", value: tags)
        }
        if let savePath = savePath, !savePath.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "savepath", value: savePath)
        }

        multipartData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return try await authedPostData(path, multipartData: multipartData, boundary: boundary).utf8String
    }

    private func appendFormField(_ data: inout Data, boundary: String, name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }

    // MARK: - Search API
    func getSearchPlugins() async throws -> [SearchPlugin] {
        let data = try await authedGetData("/api/v2/search/plugins")
        return (try? decoder.decode([SearchPlugin].self, from: data)) ?? []
    }

    func startSearch(pattern: String, plugins: [String] = ["all"], category: String? = nil) async throws -> Int? {
        var body: [String: String] = ["pattern": pattern, "plugins": plugins.joined(separator: "\n")]
        if let category = category { body["category"] = category }
        let data = try await authedPost("/api/v2/search/start", body: body)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int
    }

    func getSearchStatus(id: Int) async throws -> [String: Any]? {
        let data = try await authedGetData("/api/v2/search/status?id=\(id)")
        let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return json?.first
    }

    func getSearchResults(id: Int, limit: Int = 50, offset: Int = 0) async throws -> [SearchResult] {
        let data = try await authedGetData("/api/v2/search/results?id=\(id)&limit=\(limit)&offset=\(offset)")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []
        return results.compactMap { dict in
            guard let num = dict["num"] as? Int,
                  let descr = dict["descr"] as? String,
                  let fileName = dict["fileName"] as? String else { return nil }
            return SearchResult(
                num: num,
                descr: descr,
                fileName: fileName,
                fileSize: dict["fileSize"] as? Int ?? 0,
                nbLeechers: dict["nbLeechers"] as? Int ?? 0,
                nbSeeders: dict["nbSeeders"] as? Int ?? 0,
                siteUrl: dict["siteUrl"] as? String ?? ""
            )
        }
    }

    func stopSearch(id: Int) async throws {
        let _ = try await authedPost("/api/v2/search/stop", body: ["id": "\(id)"])
    }

    func deleteSearch(id: Int) async throws {
        let _ = try await authedPost("/api/v2/search/delete", body: ["id": "\(id)"])
    }
}

enum ApiError: LocalizedError {
    case invalidURL
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Unauthorized"
        case .networkError(let msg): return msg
        }
    }
}

extension Data {
    var utf8String: String? { String(data: self, encoding: .utf8) }
}
