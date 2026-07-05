import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        TabView(selection: $store.tab) {
            WikiView(store: store.scope(state: \.wiki, action: \.wiki))
                .tabItem { Label("Wiki", systemImage: "book") }
                .tag(AppReducer.Tab.wiki)

            ProjectsView(store: store.scope(state: \.storyboard, action: \.storyboard))
                .tabItem { Label("Storyboard", systemImage: "film") }
                .tag(AppReducer.Tab.storyboard)

            VaultspaceView(store: store.scope(state: \.vaultspace, action: \.vaultspace))
                .tabItem { Label("Vaultspace", systemImage: "square.grid.3x3") }
                .tag(AppReducer.Tab.vaultspace)

            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(AppReducer.Tab.settings)
        }
    }
}
