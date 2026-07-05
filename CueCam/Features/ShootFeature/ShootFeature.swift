import ComposableArchitecture
import Foundation

/// スクリプト付き撮影フロー:
/// preparing → ready → recording → reviewing → (OKで次のスクリプト or finished)
@Reducer
struct ShootFeature {
    @Dependency(\.cameraClient) var cameraClient

    @ObservableState
    struct State: Equatable {
        var scripts: [ShotScript]
        /// 撮影対象の名前(ボードのタイトル等)。空なら非表示
        var title = ""
        /// 親からpresentされている場合true(閉じるボタン/Doneを出す)
        var showsClose = false
        var currentIndex = 0
        var phase: Phase = .preparing
        var session: CameraSession?
        /// OK済みテイク(script.id → 動画URL)。書き出し機能で使う予定
        var approvedTakes: [String: URL] = [:]

        var currentScript: ShotScript? {
            scripts.indices.contains(currentIndex) ? scripts[currentIndex] : nil
        }

        enum Phase: Equatable {
            case preparing
            case denied
            case ready
            case recording
            case reviewing(URL)
            case finished
        }
    }

    enum Action {
        case onAppear
        case authorizationResponse(Bool)
        case sessionStarted(CameraSession?)
        case recordButtonTapped
        case recordingFinished(Result<URL, any Error>)
        case retakeTapped
        case okTapped
        case restartTapped
        case closeButtonTapped
        case delegate(Delegate)

        enum Delegate {
            case close
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.phase == .preparing else { return .none }
                return .run { send in
                    await send(.authorizationResponse(cameraClient.requestAuthorization()))
                }

            case .authorizationResponse(false):
                state.phase = .denied
                return .none

            case .authorizationResponse(true):
                return .run { send in
                    await send(.sessionStarted(cameraClient.startSession()))
                }

            case .sessionStarted(let session):
                state.session = session
                state.phase = .ready
                return .none

            case .recordButtonTapped:
                switch state.phase {
                case .ready:
                    state.phase = .recording
                    return .run { _ in await cameraClient.startRecording() }
                case .recording:
                    return .run { send in
                        do {
                            let url = try await cameraClient.stopRecording()
                            await send(.recordingFinished(.success(url)))
                        } catch {
                            await send(.recordingFinished(.failure(error)))
                        }
                    }
                default:
                    return .none
                }

            case .recordingFinished(.success(let url)):
                state.phase = .reviewing(url)
                return .none

            case .recordingFinished(.failure):
                state.phase = .ready
                return .none

            case .retakeTapped:
                guard case .reviewing(let url) = state.phase else { return .none }
                state.phase = .ready
                return .run { _ in try? FileManager.default.removeItem(at: url) }

            case .okTapped:
                guard
                    case .reviewing(let url) = state.phase,
                    let script = state.currentScript
                else { return .none }
                state.approvedTakes[script.id] = url
                if state.currentIndex + 1 < state.scripts.count {
                    state.currentIndex += 1
                    state.phase = .ready
                } else {
                    state.phase = .finished
                }
                return .none

            case .restartTapped:
                let takes = Array(state.approvedTakes.values)
                state.approvedTakes = [:]
                state.currentIndex = 0
                state.phase = .ready
                return .run { _ in
                    for url in takes {
                        try? FileManager.default.removeItem(at: url)
                    }
                }

            case .closeButtonTapped:
                return .send(.delegate(.close))

            case .delegate:
                return .none
            }
        }
    }
}
