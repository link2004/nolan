import ComposableArchitecture

@Reducer
struct AppReducer {
    enum Tab: String, CaseIterable {
        case wiki
        case storyboard
        case vaultspace
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var wiki = WikiFeature.State()
        var storyboard = ProjectsFeature.State()
        var vaultspace = VaultspaceFeature.State()
        var settings = SettingsFeature.State()
        var tab: Tab = .vaultspace
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case wiki(WikiFeature.Action)
        case storyboard(ProjectsFeature.Action)
        case vaultspace(VaultspaceFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.wiki, action: \.wiki) {
            WikiFeature()
        }
        Scope(state: \.storyboard, action: \.storyboard) {
            ProjectsFeature()
        }
        Scope(state: \.vaultspace, action: \.vaultspace) {
            VaultspaceFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            // マップの写真タップ → Wikiタブへ切り替えて該当ノートをプッシュ
            case .vaultspace(.delegate(.openWikiNote(let ref))):
                state.tab = .wiki
                state.wiki.path.append(.note(WikiNoteFeature.State(ref: ref)))
                return .none
            default:
                return .none
            }
        }
    }
}
