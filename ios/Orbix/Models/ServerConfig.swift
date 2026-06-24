import Foundation

struct ServerConfig: Codable, Identifiable, Equatable {
    var id: String { "\(host):\(port)\(username)" }

    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String
    var https: Bool

    var url: String {
        let scheme = https ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    static func == (lhs: ServerConfig, rhs: ServerConfig) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port && lhs.username == rhs.username
    }
}

enum ConnectStatus {
    case ok
    case authFailed
    case network
    case unknown

    var isSuccess: Bool { self == .ok }
}

struct ConnectResult {
    let status: ConnectStatus
    let message: String

    var isSuccess: Bool { status == .ok }

    static let ok = ConnectResult(status: .ok, message: "Connected")
    static let authFailed = ConnectResult(status: .authFailed, message: "Authentication failed")
    static let networkError = ConnectResult(status: .network, message: "Network error")

    static func unknown(_ msg: String) -> ConnectResult {
        ConnectResult(status: .unknown, message: msg)
    }
}
