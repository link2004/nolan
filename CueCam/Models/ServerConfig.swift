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

/// シミュレータはMac上で動くため localhost が既定。実機ではMacのIP/ホスト名に変更する。
enum DefaultURLs {
    static let wiki = "http://localhost:8750"
    static let storyboard = "http://localhost:8731"
    static let vaultspace = "http://localhost:8765"
}

enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}
