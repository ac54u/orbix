import Foundation

actor TorrentSearchService {
    static let shared = TorrentSearchService()
    private init() {}

    private let session = URLSession.shared

    func trending(pages: Int = 2) async throws -> [ScrapedTorrent] {
        var allResults: [ScrapedTorrent] = []

        try await withThrowingTaskGroup(of: [ScrapedTorrent].self) { group in
            for page in 1...pages {
                group.addTask {
                    try await self.fetchSearchPage(page, query: "a")
                }
            }

            for try await results in group {
                allResults.append(contentsOf: results)
            }
        }

        return allResults
    }

    func search(query: String, pages: Int = 3, startPage: Int = 1) async throws -> [ScrapedTorrent] {
        var allResults: [ScrapedTorrent] = []

        try await withThrowingTaskGroup(of: [ScrapedTorrent].self) { group in
            for page in startPage..<(startPage + pages) {
                group.addTask {
                    try await self.fetchSearchPage(page, query: query)
                }
            }

            for try await results in group {
                allResults.append(contentsOf: results)
            }
        }

        let lowerQuery = query.lowercased()
        if !lowerQuery.isEmpty {
            allResults = allResults.filter {
                $0.title.lowercased().contains(lowerQuery) ||
                $0.code.lowercased().contains(lowerQuery)
            }
        }

        return allResults
    }

    private func fetchSearchPage(_ page: Int, query: String) async throws -> [ScrapedTorrent] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://www.141ppv.com/search/?q=\(encoded)&page=\(page)"

        guard let url = URL(string: urlStr) else { return [] }

        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        return parseList(html)
    }

    private func parseList(_ html: String) -> [ScrapedTorrent] {
        var results: [ScrapedTorrent] = []

        let cardPattern = #"<div class="card mb-3">.*?</div>\s*</div>\s*</div>"#
        guard let cardRegex = try? NSRegularExpression(pattern: cardPattern, options: [.dotMatchesLineSeparators]) else {
            return results
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = cardRegex.matches(in: html, range: nsRange)

        for match in matches {
            guard let range = Range(match.range, in: html) else { continue }
            let card = String(html[range])

            guard let torrent = parseCard(card) else { continue }
            results.append(torrent)
        }

        return results
    }

    private func parseCard(_ card: String) -> ScrapedTorrent? {
        let code = extract(from: card, pattern: #"href="/torrent/([^"]+)""#) ?? ""
        guard !code.isEmpty else { return nil }

        let title = extract(from: card, pattern: #"class="title is-4 is-spaced">.*?<a[^>]*>([^<]+)</a>"#)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? code
        let thumbnail = extract(from: card, pattern: #"<img[^>]*src="([^"]+\.(?:jpg|jpeg|png|webp|avif))"#)
        let magnet = extract(from: card, pattern: #"href="(magnet:\?[^"]+)""#) ?? ""
        let torrentUrl = extract(from: card, pattern: #"href="(/download/[^"]+\.torrent)"#)
        let pageUrl = extract(from: card, pattern: #"href="(/torrent/[^"]+)""#)
        let size = extract(from: card, pattern: #"class="is-size-6 has-text-grey">([^<]+)"#) ?? "N/A"
        let date = extract(from: card, pattern: #"subtitle is-6">.*?<a[^>]*>([^<]+)</a>"#) ?? ""
        let desc = extract(from: card, pattern: #"class="level has-text-grey-dark">(.*?)</p>"#)

        return ScrapedTorrent(
            code: code,
            title: title,
            size: size,
            date: date,
            thumbnail: thumbnail,
            magnet: magnet,
            torrentUrl: torrentUrl,
            pageUrl: pageUrl,
            description: desc
        )
    }

    private func extract(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
