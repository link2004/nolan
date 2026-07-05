import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct CueCamApp: App {
    // 通常は縦固定、撮影画面(ShootView)表示中のみ横向きにする (ADR-004)
    @UIApplicationDelegateAdaptor(OrientationLockDelegate.self) private var orientationDelegate

    static let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }

    init() {
        // LAN上のMacサーバーから読むメディア(静止画/クリップ)のキャッシュ用。
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
