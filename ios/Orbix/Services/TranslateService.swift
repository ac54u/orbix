import Foundation

actor TranslateService {
    static let shared = TranslateService()
    private init() {}

    private let session = URLSession.shared

    func toChinese(_ text: String) async throws -> String {
        guard !text.isEmpty else { return text }

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlStr = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=zh-CN&dt=t&q=\(encoded)"

        guard let url = URL(string: urlStr) else { return text }

        let (data, _) = try await session.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [Any] else {
            return text
        }

        let translated = sentences.compactMap { item -> String? in
            if let arr = item as? [Any], let str = arr.first as? String {
                return str
            }
            return nil
        }.joined()

        return translated.isEmpty ? text : translated
    }
}
