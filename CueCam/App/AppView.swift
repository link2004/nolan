import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        HomeView(store: store.scope(state: \.home, action: \.home))
            .fullScreenCover(
                item: $store.scope(state: \.shoot, action: \.shoot)
            ) { shootStore in
                ShootView(store: shootStore)
            }
    }
}
