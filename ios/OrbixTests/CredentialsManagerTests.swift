import XCTest
@testable import Orbix
import Foundation

@MainActor
final class CredentialsManagerTests: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        CredentialsManager.testSession = session
    }

    override func tearDown() {
        MockURLProtocol.reset()
        CredentialsManager.testSession = .shared
        session = nil
        super.tearDown()
    }

    // MARK: - qBittorrent

    func testConnection_qBittorrent_success() async {
        MockURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.contains("/auth/login") ?? false)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent, host: "10.0.0.1", port: 8080, https: false,
            username: "admin", password: "pass"
        )
        XCTAssertTrue(result.isSuccess)
    }

    func testConnection_qBittorrent_insecureShowsWarning() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "http://test.local:8080/api/v2/auth/login")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent, host: "test.local", port: 8080, https: false,
            username: "admin", password: "pass"
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.message.contains("HTTPS"))
    }

    func testConnection_qBittorrent_https_noWarning() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test.local:443/api/v2/auth/login")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent, host: "test.local", port: 443, https: true,
            username: "admin", password: "pass"
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertFalse(result.message.contains("HTTPS"))
    }

    func testConnection_qBittorrent_authFailed() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "http://test:8080/api/v2/auth/login")!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent, host: "test", port: 8080, https: false,
            username: "admin", password: "wrong"
        )
        XCTAssertEqual(result, .authFailed)
    }

    func testConnection_qBittorrent_timeout() async {
        MockURLProtocol.responseHandler = { _ in
            throw URLError(.timedOut)
        }

        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent, host: "test", port: 8080, https: false,
            username: "u", password: "p"
        )
        XCTAssertEqual(result, .timeout)
    }

    func testConnection_qBittorrent_invalidHost() async {
        let result = await CredentialsManager.testConnection(
            kind: .qBittorrent,
            host: "http://\ninvalid", port: 0, https: false,
            username: "u", password: "p"
        )
        XCTAssertFalse(result.isSuccess)
    }

    // MARK: - Prowlarr

    func testConnection_prowlarr_success() async {
        MockURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Api-Key"], "test-key")
            XCTAssertTrue(request.url?.absoluteString.contains("/api/v1/system/status") ?? false)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .prowlarr, host: "test", port: 9696, https: true,
            apiKey: "test-key"
        )
        XCTAssertTrue(result.isSuccess)
    }

    // MARK: - Radarr

    func testConnection_radarr_success() async {
        MockURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Api-Key"], "radarr-key")
            XCTAssertTrue(request.url?.absoluteString.contains("/api/v3/system/status") ?? false)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let result = await CredentialsManager.testConnection(
            kind: .radarr, host: "test", port: 7878, https: true,
            apiKey: "radarr-key"
        )
        XCTAssertTrue(result.isSuccess)
    }
}
