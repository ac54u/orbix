import Foundation

actor QBitApi {
    static let shared = QBitApi()
    private init() {}

    // MARK: - State
    var activeServer: ServerConfig?
    let session = URLSession(configuration: .ephemeral)
    let decoder = JSONDecoder()

    // MARK: - Server Management
    func loadSavedConfig() -> ServerConfig? {
        guard let host = KeychainService.loadString(forKey: "qbit_host") else {
            guard let legacyHost = UserDefaults.standard.string(forKey: "qbit_host") else { return nil }
            let config = ServerConfig(
                name: UserDefaults.standard.string(forKey: "qbit_name") ?? legacyHost,
                host: legacyHost,
                port: UserDefaults.standard.integer(forKey: "qbit_port"),
                username: UserDefaults.standard.string(forKey: "qbit_username") ?? "",
                password: UserDefaults.standard.string(forKey: "qbit_password") ?? "",
                https: UserDefaults.standard.bool(forKey: "qbit_https")
            )
            setActiveServer(config)
            removeLegacyKeys()
            return config
        }
        return ServerConfig(
            name: KeychainService.loadString(forKey: "qbit_name") ?? host,
            host: host,
            port: Int(KeychainService.loadString(forKey: "qbit_port") ?? "") ?? 0,
            username: KeychainService.loadString(forKey: "qbit_username") ?? "",
            password: KeychainService.loadString(forKey: "qbit_password") ?? "",
            https: KeychainService.loadString(forKey: "qbit_https") == "true"
        )
    }

    func setActiveServer(_ config: ServerConfig) {
        activeServer = config
        KeychainService.saveString(config.name, forKey: "qbit_name")
        KeychainService.saveString(config.host, forKey: "qbit_host")
        KeychainService.saveString(String(config.port), forKey: "qbit_port")
        KeychainService.saveString(config.username, forKey: "qbit_username")
        KeychainService.saveString(config.password, forKey: "qbit_password")
        KeychainService.saveString(config.https ? "true" : "false", forKey: "qbit_https")
        removeLegacyKeys()
    }

    func loadServers() -> [ServerConfig] {
        if let data = KeychainService.load(key: "qbit_servers"),
           let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            return servers
        }
        if let data = UserDefaults.standard.data(forKey: "qbit_servers"),
           let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            if let encoded = try? JSONEncoder().encode(servers) {
                _ = KeychainService.save(key: "qbit_servers", data: encoded)
            }
            UserDefaults.standard.removeObject(forKey: "qbit_servers")
            return servers
        }
        if let legacy = legacyServerConfig() {
            return [legacy]
        }
        return []
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
        _ = KeychainService.save(key: "qbit_servers", data: data)
        UserDefaults.standard.removeObject(forKey: "qbit_servers")
    }

    private func removeLegacyKeys() {
        let keys = ["qbit_name", "qbit_host", "qbit_port", "qbit_username", "qbit_password", "qbit_https"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func legacyServerConfig() -> ServerConfig? {
        guard let host = KeychainService.loadString(forKey: "qbit_host") ??
                UserDefaults.standard.string(forKey: "qbit_host") else { return nil }
        let port: Int = Int(KeychainService.loadString(forKey: "qbit_port") ?? "") ?? UserDefaults.standard.integer(forKey: "qbit_port")
        let username = KeychainService.loadString(forKey: "qbit_username") ?? UserDefaults.standard.string(forKey: "qbit_username") ?? ""
        let password = KeychainService.loadString(forKey: "qbit_password") ?? UserDefaults.standard.string(forKey: "qbit_password") ?? ""
        let https: Bool = KeychainService.loadString(forKey: "qbit_https").map { $0 == "true" } ?? UserDefaults.standard.bool(forKey: "qbit_https")

        guard !username.isEmpty else { return nil }

        let config = ServerConfig(
            name: KeychainService.loadString(forKey: "qbit_name") ?? UserDefaults.standard.string(forKey: "qbit_name") ?? "Default",
            host: host,
            port: port,
            username: username,
            password: password,
            https: https
        )

        setActiveServer(config)
        removeLegacyKeys()
        return config
    }

    // MARK: - URL Building
    static func buildUrl(host: String, port: Int, https: Bool) -> String {
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            let cleaned = host
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let scheme = https ? "https" : "http"
            return "\(scheme)://\(cleaned):\(port)"
        }
        let scheme = https ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    func apiUrl(_ path: String) -> URL? {
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

    func login(server: ServerConfig) async -> ConnectResult {
        guard let url = URL(string: "\(server.url)/api/v2/auth/login") else {
            return ConnectResult(status: .unknown, message: "Invalid URL")
        }

        return await attemptLogin(url: url, server: server, remainingAttempts: 2)
    }

    private func attemptLogin(url: URL, server: ServerConfig, remainingAttempts: Int) async -> ConnectResult {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(server.url, forHTTPHeaderField: "Origin")
        req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encUser = server.username.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let encPass = server.password.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let body = "username=\(encUser)&password=\(encPass)"
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = NetworkTimeout.login

        do {
            let (_, response) = try await session.data(for: req)
            guard let httpResp = response as? HTTPURLResponse else {
                return ConnectResult(status: .unknown, message: "Invalid response")
            }

            if httpResp.statusCode == 200 {
                return .ok
            } else if httpResp.statusCode == 403 {
                return .authFailed
            } else {
                return ConnectResult(status: .network, message: "HTTP \(httpResp.statusCode)")
            }
        } catch {
            if remainingAttempts > 1 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return await attemptLogin(url: url, server: server, remainingAttempts: remainingAttempts - 1)
            }
            return .networkError
        }
    }

    // MARK: - Authenticated Request
    func authedGet<T: Decodable>(_ path: String, type: T.Type) async throws -> T? {
        var lastError: Error = ApiError.invalidURL
        for attempt in 0..<2 {
            do {
                guard let url = apiUrl(path) else { throw ApiError.invalidURL }
                var req = URLRequest(url: url)
                req.timeoutInterval = NetworkTimeout.brief
                let (data, response) = try await session.data(for: req)
                try checkAuth(response: response)
                return try? decoder.decode(T.self, from: data)
            } catch {
                lastError = error
                if attempt == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
        }
        throw lastError
    }

    func authedGetData(_ path: String) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.timeoutInterval = NetworkTimeout.brief

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    func authedPost(_ path: String, body: [String: String]) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = NetworkTimeout.brief

        let bodyStr = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        req.httpBody = bodyStr.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    func authedPostData(_ path: String, multipartData: Data, boundary: String) async throws -> Data {
        guard let url = apiUrl(path) else { throw ApiError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = NetworkTimeout.download
        req.httpBody = multipartData

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return data
    }

    func checkAuth(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 || http.statusCode == 403 {
            Task { await renewSession() }
            throw ApiError.unauthorized
        }
    }

    func renewSession() async {
        guard let server = activeServer else { return }
        _ = await login(server: server)
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
