import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        TabView(selection: $store.tab) {
            VaultspaceView(store: store.scope(state: \.vaultspace, action: \.vaultspace))
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppReducer.Tab.vaultspace)

            ProjectsView(store: store.scope(state: \.storyboard, action: \.storyboard))
                .tabItem { Label("Storyboard", systemImage: "film") }
                .tag(AppReducer.Tab.storyboard)

            WikiView(store: store.scope(state: \.wiki, action: \.wiki))
                .tabItem { Label("Wiki", systemImage: "book") }
                .tag(AppReducer.Tab.wiki)

            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppReducer.Tab.settings)
        }
    }
}
