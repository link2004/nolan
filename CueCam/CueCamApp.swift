import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct CueCamApp: App {
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
