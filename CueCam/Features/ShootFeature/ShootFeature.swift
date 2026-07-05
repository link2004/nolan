import ComposableArchitecture
import Foundation

@Reducer
struct ShootFeature {
    @Dependency(\.directorClient) var directorClient

    @ObservableState
    struct State: Equatable {
        let theme: String
        var shotPlan: [ShotInstruction] = []
        var currentShotIndex = 0
        var isLoadingPlan = false
        var isRecording = false
        var loadError: String?

        var currentShot: ShotInstruction? {
            shotPlan.indices.contains(currentShotIndex) ? shotPlan[currentShotIndex] : nil
        }

        var isLastShot: Bool {
            currentShotIndex >= shotPlan.count - 1
        }
    }

    enum Action {
        case onAppear
        case shotPlanLoaded(Result<[ShotInstruction], Error>)
        case recordButtonTapped
        case nextShotButtonTapped
        case closeButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case finished
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.shotPlan.isEmpty, !state.isLoadingPlan else { return .none }
                state.isLoadingPlan = true
                return .run { [theme = state.theme] send in
                    let result = await Result { try await directorClient.makeShotPlan(theme) }
                    await send(.shotPlanLoaded(result))
                }

            case .shotPlanLoaded(.success(let plan)):
                state.isLoadingPlan = false
                state.shotPlan = plan
                return .none

            case .shotPlanLoaded(.failure(let error)):
                state.isLoadingPlan = false
                state.loadError = error.localizedDescription
                return .none

            case .recordButtonTapped:
                // TODO: CameraClient経由で実際の録画開始/停止を行う
                state.isRecording.toggle()
                return .none

            case .nextShotButtonTapped:
                if state.isLastShot {
                    return .send(.delegate(.finished))
                }
                state.currentShotIndex += 1
                state.isRecording = false
                return .none

            case .closeButtonTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
