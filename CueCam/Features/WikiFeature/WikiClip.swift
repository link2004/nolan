import Foundation

/// Wikiノートに埋め込まれた動画カット1本。
/// contentIndex.json のplaintextには動画が残らないため、サイト(Quartz)の
/// レンダリング済みノートHTMLを取得し、その中の <video src> を出現順に拾ったもの。
struct WikiClip: Equatable, Sendable, Identifiable {
    let index: Int
    let url: URL
    /// 直前の見出し(auto:evidence/auto:videos各 h3 相当、例: "Foo · 0:08 ↗")。
    /// plaintext本文にこの文字列がそのまま現れるため、動画を差し込む位置のアンカーに使う。
    let source: String?
    var id: Int { index }
}

/// ノートHTMLから動画カットを取り出すユーティリティ。Quartzのクリーンurl(拡張子なし)と
/// 素の静的サーバー(.html付き)の両方に耐えるよう2通り試す。
enum WikiClipHTML {
    static func fetch(base: URL, slug: String) async -> [WikiClip] {
        for candidate in [slug, slug + ".html"] {
            guard let url = pageURL(base: base, path: candidate) else { continue }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let html = String(data: data, encoding: .utf8) else { continue }
                // ページ取得に成功したら、動画の有無に関わらずそのページの結果を採用する
                // (成功時に .html を追試すると同じページを二度読みしてしまうため)。
                return clips(in: html)
            } catch { continue }
        }
        return []
    }

    /// レンダリング済みHTMLから <video src> を出現順に抽出し、直前の <h3> を出典ラベルとして添える。
    static func clips(in html: String) -> [WikiClip] {
        let ns = html as NSString
        let videoRegex = try! NSRegularExpression(
            pattern: "<video\\b[^>]*\\bsrc=\"([^\"]+)\"", options: [.caseInsensitive])
        let matches = videoRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        var clips: [WikiClip] = []
        var prevEnd = 0
        for match in matches {
            defer { prevEnd = match.range.upperBound }
            let src = WikiIndexStore.decodeEntities(ns.substring(with: match.range(at: 1)))
            guard let url = URL(string: src) else { continue }
            let preamble = ns.substring(with: NSRange(location: prevEnd, length: match.range.location - prevEnd))
            clips.append(WikiClip(index: clips.count, url: url, source: lastHeading(in: preamble)))
        }
        return clips
    }

    // MARK: - helpers

    private static func pageURL(base: URL, path: String) -> URL? {
        let encoded = path
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        return URL(string: encoded, relativeTo: base)?.absoluteURL
    }

    /// 直前の <h3>…</h3> の可視テキスト(タグ除去・空白整形)。無ければnil。
    private static func lastHeading(in html: String) -> String? {
        let regex = try! NSRegularExpression(pattern: "<h3\\b[^>]*>(.*?)</h3>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ns = html as NSString
        guard let match = regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).last else { return nil }
        let text = strippingTags(ns.substring(with: match.range(at: 1)))
        return text.isEmpty ? nil : text
    }

    private static func strippingTags(_ html: String) -> String {
        let noTags = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = WikiIndexStore.decodeEntities(noTags)
        return decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
