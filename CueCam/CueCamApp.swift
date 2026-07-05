import ComposableArchitecture
import SwiftUI

@main
struct CueCamApp: App {
    static let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
