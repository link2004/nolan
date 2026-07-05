import ComposableArchitecture
import Foundation

/// 詳細シートは親がセット済みのデータを表示するだけ(アクションなし)。
@Reducer
struct VideoDetailFeature {
    @ObservableState
    struct State: Equatable {
        let video: VaultVideo
        let clips: [VaultClip]
        let stills: [VaultStill]
        let base: URL?
    }

    enum Action {}

    var body: some ReducerOf<Self> { EmptyReducer() }
}
