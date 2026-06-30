import Foundation

// MARK: - Service Kinds
enum ServiceKind: String, Codable, CaseIterable {
    case qBittorrent = "qBittorrent"
    case prowlarr = "Prowlarr"
    case radarr = "Radarr"

    var icon: String {
        switch self {
        case .qBittorrent: return "arrow.down.circle"
        case .prowlarr: return "antenna.radiowaves.left.and.right"
        case .radarr: return "film"
        }
    }
}

// MARK: - Credential Model
struct ServiceCredential: Codable, Identifiable, Equatable {
    var id: String { "\(kind.rawValue)_\(host):\(port)" }
    var kind: ServiceKind
    var name: String
    var host: String
    var port: Int
    var https: Bool
    var apiKey: String
    var username: String
    var password: String

    var baseURL: String {
        let scheme = https ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    var apiURL: String {
        switch kind {
        case .qBittorrent: return baseURL
        case .prowlarr: return "\(baseURL)/api/v1"
        case .radarr: return "\(baseURL)/api/v3"
        }
    }
}

// MARK: - Credentials Manager
@MainActor
final class CredentialsManager: ObservableObject {
    static let shared = CredentialsManager()

    @Published var qBittorrent: ServiceCredential?
    @Published var prowlarr: ServiceCredential?
    @Published var radarr: ServiceCredential?

    private let key = "service_credentials"

    private init() { loadAll() }

    // MARK: - Load / Save
    private func loadAll() {
        guard let data = KeychainService.load(key: key),
              let list = try? JSONDecoder().decode([ServiceCredential].self, from: data)
        else { return }
        for cred in list {
            switch cred.kind {
            case .qBittorrent: qBittorrent = cred
            case .prowlarr: prowlarr = cred
            case .radarr: radarr = cred
            }
        }
    }

    func save(_ credential: ServiceCredential) {
        var list = allCredentials
        list.removeAll { $0.kind == credential.kind }
        list.append(credential)
        persist(list)

        switch credential.kind {
        case .qBittorrent: qBittorrent = credential
        case .prowlarr: prowlarr = credential
        case .radarr: radarr = credential
        }
    }

    func remove(_ kind: ServiceKind) {
        var list = allCredentials
        list.removeAll { $0.kind == kind }
        persist(list)

        switch kind {
        case .qBittorrent: qBittorrent = nil
        case .prowlarr: prowlarr = nil
        case .radarr: radarr = nil
        }
    }

    var allCredentials: [ServiceCredential] {
        [qBittorrent, prowlarr, radarr].compactMap { $0 }
    }

    var activeServices: [ServiceKind] {
        allCredentials.map(\.kind)
    }

    func credential(for kind: ServiceKind) -> ServiceCredential? {
        switch kind {
        case .qBittorrent: return qBittorrent
        case .prowlarr: return prowlarr
        case .radarr: return radarr
        }
    }

    private func persist(_ list: [ServiceCredential]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        _ = KeychainService.save(key: key, data: data)
    }

    static var testSession: URLSession = .shared

    // MARK: - Connection Test
    enum TestResult: Equatable {
        case ok
        case okInsecure
        case invalidHost
        case authFailed
        case timeout
        case unknown(String)

        var message: String {
            switch self {
            case .ok: return OrbixStrings.connSuccess
            case .okInsecure: return OrbixStrings.connSuccess + "\n" + String(localized: "注意：未启用 HTTPS，凭证将以明文传输", comment: "Insecure HTTP warning")
            case .invalidHost: return OrbixStrings.connInvalidHost
            case .authFailed: return OrbixStrings.connAuthFailed
            case .timeout: return OrbixStrings.connTimeout
            case .unknown(let m): return m
            }
        }

        var isSuccess: Bool { self == .ok || self == .okInsecure }
    }

    static func testConnection(
        kind: ServiceKind,
        host: String,
        port: Int,
        https: Bool,
        apiKey: String = "",
        username: String = "",
        password: String = ""
    ) async -> TestResult {
        let cleanHost = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let scheme = https ? "https" : "http"
        let base = "\(scheme)://\(cleanHost):\(port)"

        let endpoint: String
        var httpMethod = "GET"
        var headers: [String: String] = [:]
        var body: Data?

        switch kind {
        case .qBittorrent:
            httpMethod = "POST"
            endpoint = "\(base)/api/v2/auth/login"
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            let encUser = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let encPass = password.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            headers["Origin"] = base
            headers["Referer"] = "\(base)/"
            body = "username=\(encUser)&password=\(encPass)".data(using: .utf8)
        case .prowlarr:
            endpoint = "\(base)/api/v1/system/status"
            headers["X-Api-Key"] = apiKey
        case .radarr:
            endpoint = "\(base)/api/v3/system/status"
            headers["X-Api-Key"] = apiKey
        }

        guard let url = URL(string: endpoint) else { return .invalidHost }

        var req = URLRequest(url: url)
        req.httpMethod = httpMethod
        req.timeoutInterval = NetworkTimeout.login
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body

        do {
            let (_, response) = try await Self.testSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .unknown(OrbixStrings.connUnknown) }
            if http.statusCode == 200 {
                if kind == .qBittorrent && !https { return .okInsecure }
                return .ok
            }
            if http.statusCode == 401 || http.statusCode == 403 { return .authFailed }
            return .unknown(String(format: OrbixStrings.connServerReturn, http.statusCode, endpoint))
        } catch let err as URLError {
            if err.code == .timedOut { return .timeout }
            return .unknown(String(format: OrbixStrings.connUnableConnect, endpoint, err.localizedDescription))
        } catch {
            return .unknown(error.localizedDescription)
        }
    }
}
