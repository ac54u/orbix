import Foundation

struct ScrapedTorrent: Codable, Identifiable, Equatable {
    var id: String { code }
    let code: String
    let title: String
    let size: String
    let date: String
    let thumbnail: String?
    let magnet: String
    let torrentUrl: String?
    let pageUrl: String?
    let description: String?

    static func == (lhs: ScrapedTorrent, rhs: ScrapedTorrent) -> Bool {
        lhs.code == rhs.code
    }
}
