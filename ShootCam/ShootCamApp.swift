import ComposableArchitecture
import SwiftUI

// ShootFeature 単体を実機で動かすための起動シェル。
// CueCam 本体への統合方針が決まったらこのターゲットは削除する予定 (ADR-003)
@main
struct ShootCamApp: App {
    static let store = Store(initialState: ShootFeature.State(scripts: .mock)) {
        ShootFeature()
    }

    var body: some Scene {
        WindowGroup {
            ShootView(store: Self.store)
        }
    }
}
