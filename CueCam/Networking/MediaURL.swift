import Foundation

/// `/media/<key>` URLの組み立て。キーはvault相対パスで、スペースやemダッシュを含むため
/// セグメント毎にパーセントエンコードする(`/`は区切りとして残す)。SPAのmediaUrl()と同じ規則。
enum MediaURL {
    private static let segmentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/?%#[]&+;=")
        return set
    }()

    /// 生のメディアキー(例: "technique-clips/video — Foo.mp4")からURLを組み立てる。
    static func url(base: URL, key: String) -> URL? {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let encoded = trimmed
            .split(separator: "/")
            .map { seg in String(seg).addingPercentEncoding(withAllowedCharacters: segmentAllowed) ?? String(seg) }
            .joined(separator: "/")
        return URL(string: "/media/" + encoded, relativeTo: base)?.absoluteURL
    }

    /// Vaultspaceのmanifestが返す既成パス("/media/<encoded-key>")からURLを組み立てる。
    /// 二重エンコードを避けるため、一度デコードしてから再構築する。
    static func url(base: URL, mediaPath: String) -> URL? {
        var key = mediaPath
        if key.hasPrefix("/media/") { key = String(key.dropFirst("/media/".count)) }
        return url(base: base, key: key.removingPercentEncoding ?? key)
    }
}
