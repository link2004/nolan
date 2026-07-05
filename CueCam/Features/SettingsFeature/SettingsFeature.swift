import ComposableArchitecture
import Foundation

enum ProbeStatus: Equatable, Sendable {
    case unknown
    case checking
    case ok(milliseconds: Int)
    case failed(String)
}

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var urls: [VaultSurface: String] = [:]
        var probes: [VaultSurface: ProbeStatus] = [:]
    }

    enum Action {
        case task
        case urlChanged(VaultSurface, String)
        case probeAll
        case probeResult(VaultSurface, ProbeStatus)
    }

    @Dependency(\.serverConfig) var serverConfig

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                for surface in VaultSurface.allCases {
                    state.urls[surface] = serverConfig.baseURLString(surface)
                }
                return .send(.probeAll)

            case .urlChanged(let surface, let value):
                state.urls[surface] = value
                serverConfig.setBaseURL(surface, value)
                state.probes[surface] = .unknown
                return .none

            case .probeAll:
                for surface in VaultSurface.allCases {
                    state.probes[surface] = .checking
                }
                return .merge(VaultSurface.allCases.map { surface in
                    .run { send in
                        await send(.probeResult(surface, Self.probe(surface, config: serverConfig)))
                    }
                })

            case .probeResult(let surface, let status):
                state.probes[surface] = status
                return .none
            }
        }
    }

    /// 各サーフェスの軽量エンドポイントを叩いて到達性とレイテンシを測る。
    private static func probe(_ surface: VaultSurface, config: ServerConfigClient) async -> ProbeStatus {
        do {
            let base = try config.baseURL(surface)
            let path = switch surface {
            case .wiki: "/static/contentIndex.json"
            case .storyboard: "/api/projects"
            case .vaultspace: "/api/space"
            }
            guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
                return .failed("不正なURL")
            }
            var request = URLRequest(url: url, timeoutInterval: 5)
            if surface == .wiki { request.httpMethod = "HEAD" }
            let start = ContinuousClock.now
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = start.duration(to: .now)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let ms = Int(elapsed.components.seconds * 1000)
                + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
            return .ok(milliseconds: ms)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
