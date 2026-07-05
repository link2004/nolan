import ComposableArchitecture
import SwiftUI

// ShootFeature 単体を実機で動かすための起動シェル。
// CueCam 本体(Ten-K Vault クライアント)のルート再構築が落ち着いたら、
// ShootFeature をタブとして組み込みこのターゲットは削除する予定 (ADR-002)
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
