import ComposableArchitecture
import SwiftUI

/// タブなし。ルート = Vaultキャンバス(ホーム)、全画面を1本のNavigationStackに積む。
/// Wiki / Storyboard へはホーム四隅のタイポグラフィ(WIKI / MAKE VIDEO)から遷移する。
struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>
    /// 写真→Wikiノートのズームトランジション用ネームスペース
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VaultspaceView(
                store: store.scope(state: \.home, action: \.home),
                zoomNamespace: zoomNamespace
            )
        } destination: { pathStore in
            switch pathStore.case {
            case .wiki(let store):
                WikiView(store: store)
            case .folder(let store):
                WikiFolderView(store: store)
            case .note(let noteStore):
                noteDestination(noteStore)
            case .tag(let store):
                WikiTagView(store: store)
            case .storyboard(let store):
                ProjectsView(store: store)
            case .board(let store):
                BoardView(store: store)
            case .settings(let store):
                SettingsView(store: store)
            }
        }
    }

    /// タップした写真からのプッシュだけズームで開く(リンク遷移などは通常遷移)。
    @ViewBuilder
    private func noteDestination(_ noteStore: StoreOf<WikiNoteFeature>) -> some View {
        if store.home.zoomAnchor?.slug == noteStore.slug {
            WikiNoteView(store: noteStore)
                .navigationTransition(.zoom(sourceID: noteStore.slug, in: zoomNamespace))
        } else {
            WikiNoteView(store: noteStore)
        }
    }
}
