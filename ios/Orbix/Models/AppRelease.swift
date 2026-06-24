import Foundation

struct AppRelease: Decodable, Identifiable {
    var id: String { tag }
    let tag: String
    let notes: String
    let ipaUrl: String?
    let ipaSize: Int64?
    let htmlUrl: String

    var version: String { tag }

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case notes = "body"
        case assets = "assets"
        case htmlUrl = "html_url"
    }

    struct Asset: Decodable {
        let name: String
        let size: Int64
        let url: String?

        enum CodingKeys: String, CodingKey {
            case name = "name"
            case size = "size"
            case url = "browser_download_url"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tag = try container.decode(String.self, forKey: .tag)
        notes = (try? container.decode(String.self, forKey: .notes)) ?? ""
        htmlUrl = (try? container.decode(String.self, forKey: .htmlUrl)) ?? ""

        let assets = try? container.decode([Asset].self, forKey: .assets)
        let ipaAsset = assets?.first(where: { $0.name.hasSuffix(".ipa") })
        ipaUrl = ipaAsset?.url
        ipaSize = ipaAsset?.size
    }
}

struct UpdateCheck {
    let hasUpdate: Bool
    let currentVersion: String
    let latest: AppRelease?
    let error: String?

    static func upToDate(_ version: String) -> UpdateCheck {
        UpdateCheck(hasUpdate: false, currentVersion: version, latest: nil, error: nil)
    }

    static func available(_ version: String, release: AppRelease) -> UpdateCheck {
        UpdateCheck(hasUpdate: true, currentVersion: version, latest: release, error: nil)
    }

    static func failed(_ version: String, error: String) -> UpdateCheck {
        UpdateCheck(hasUpdate: false, currentVersion: version, latest: nil, error: error)
    }
}
