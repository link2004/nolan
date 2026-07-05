import Foundation

/// メディアURLの組み立て。Macのローカルサーバー(/media/ 302リダイレクト)は経由せず、
/// R2の公開ホスト(既定: media.tenkstudios.com)から直接取得する。
/// キーはvault相対パスで、スペースやemダッシュを含むためセグメント毎にパーセントエンコードする。
enum MediaURL {
    static let configKey = "baseURL.media"

    static var mediaBase: URL? {
        let stored = UserDefaults.standard.string(forKey: configKey) ?? DefaultURLs.media
        return try? HTTP.baseURL(stored)
    }

    private static let segmentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/?%#[]&+;=")
        return set
    }()

    /// 生のメディアキー(例: "technique-clips/video — Foo.mp4")からURLを組み立てる。
    static func url(key: String) -> URL? {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let base = mediaBase else { return nil }
        let encoded = trimmed
            .split(separator: "/")
            .map { seg in String(seg).addingPercentEncoding(withAllowedCharacters: segmentAllowed) ?? String(seg) }
            .joined(separator: "/")
        return URL(string: "/" + encoded, relativeTo: base)?.absoluteURL
    }

    /// Vaultspaceのmanifestが返す既成パス("/media/<encoded-key>")からURLを組み立てる。
    /// 二重エンコードを避けるため、一度デコードしてから再構築する。
    static func url(mediaPath: String) -> URL? {
        var key = mediaPath
        if key.hasPrefix("/media/") { key = String(key.dropFirst("/media/".count)) }
        return url(key: key.removingPercentEncoding ?? key)
    }
}
