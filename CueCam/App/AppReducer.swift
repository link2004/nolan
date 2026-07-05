import ComposableArchitecture
import Foundation

/// タブなしの単一スタック構成。ルート = Vaultキャンバス(ホーム)。
/// Wiki / Storyboard / 設定はすべてホームから1本のNavigationStackに積む。
@Reducer
struct AppReducer {
    @Reducer(state: .equatable)
    enum Path {
        case wiki(WikiFeature)             // Wikiルート(エクスプローラ/検索)
        case folder(WikiFolderFeature)
        case note(WikiNoteFeature)
        case tag(WikiTagFeature)
        case storyboard(ProjectsFeature)
        case board(BoardFeature)
        case settings(SettingsFeature)
    }

    @ObservableState
    struct State: Equatable {
        var home = VaultspaceFeature.State()
        var path = StackState<Path.State>()
    }

    enum Action {
        case home(VaultspaceFeature.Action)
        case path(StackActionOf<Path>)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            VaultspaceFeature()
        }
        Reduce { state, action in
            switch action {
            // 写真タップ → Wikiノートをズームトランジションでプッシュ
            case .home(.delegate(.openWikiNote(let ref))):
                state.path.append(.note(WikiNoteFeature.State(ref: ref)))
                return .none
            case .home:
                return .none
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
