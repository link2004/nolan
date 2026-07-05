import SwiftUI
import UIKit

/// 縦固定のCueCam本体で撮影画面だけ横向きにするためのロック。
/// CueCamApp が @UIApplicationDelegateAdaptor で接続する。
/// ShootCam(横固定plist)は未接続のため lock() は実質no-op
@MainActor
final class OrientationLockDelegate: NSObject, UIApplicationDelegate {
    static var mask: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.mask
    }
}

@MainActor
enum OrientationLock {
    static func lock(_ mask: UIInterfaceOrientationMask) {
        OrientationLockDelegate.mask = mask
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
