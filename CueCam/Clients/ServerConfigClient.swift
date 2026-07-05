import ComposableArchitecture
import Foundation

/// ベースURL設定(UserDefaults)。各featureはロード時に読むだけなので、
/// 共有Stateではなく依存クライアントで十分。
@DependencyClient
struct ServerConfigClient {
    var baseURLString: @Sendable (VaultSurface) -> String = { _ in "" }
    var setBaseURL: @Sendable (VaultSurface, String) -> Void
    var mediaBaseString: @Sendable () -> String = { DefaultURLs.media }
    var setMediaBase: @Sendable (String) -> Void

    func baseURL(_ surface: VaultSurface) throws -> URL {
        try HTTP.baseURL(baseURLString(surface))
    }
}

extension ServerConfigClient: DependencyKey {
    private static func key(_ surface: VaultSurface) -> String { "baseURL.\(surface.rawValue)" }

    private static func defaultURL(_ surface: VaultSurface) -> String {
        switch surface {
        case .wiki: DefaultURLs.wiki
        case .storyboard: DefaultURLs.storyboard
        case .vaultspace: DefaultURLs.vaultspace
        }
    }

    static let liveValue = ServerConfigClient(
        baseURLString: { surface in
            UserDefaults.standard.string(forKey: key(surface)) ?? defaultURL(surface)
        },
        setBaseURL: { surface, value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: key(surface))
            } else {
                UserDefaults.standard.set(trimmed, forKey: key(surface))
            }
        },
        mediaBaseString: {
            UserDefaults.standard.string(forKey: MediaURL.configKey) ?? DefaultURLs.media
        },
        setMediaBase: { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: MediaURL.configKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: MediaURL.configKey)
            }
        }
    )
}

extension DependencyValues {
    var serverConfig: ServerConfigClient {
        get { self[ServerConfigClient.self] }
        set { self[ServerConfigClient.self] = newValue }
    }
}
