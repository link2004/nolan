import Foundation

/// Mac上のローカルサーバー3系統。ベースURLは設定タブで変更可能(@Shared(.appStorage))。
enum VaultSurface: String, CaseIterable, Identifiable, Sendable {
    case wiki
    case storyboard
    case vaultspace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wiki: "Wiki"
        case .storyboard: "Storyboard"
        case .vaultspace: "Vaultspace"
        }
    }
}

/// 実機からMacのローカルサーバーへ届くよう、MacのLAN IPを既定にする(設定タブで変更可能)。
/// media はR2公開ホスト — 画像・動画はローカルサーバーを経由せずここから直接取得する。
enum DefaultURLs {
    static let wiki = "http://192.168.0.215:8750"
    static let storyboard = "http://192.168.0.215:8731"
    static let vaultspace = "http://192.168.0.215:8766"
    static let media = "https://media.tenkstudios.com"
}

enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}
