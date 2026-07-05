import Foundation

/// ラインに紐づく参照メディア(お手本)。
/// ShootCam ターゲットにも入るため SBReference/MediaURL には依存しない解決済みの形
struct ShotReference: Equatable, Sendable {
    let isClip: Bool
    let url: URL
    let posterURL: URL?
}

/// 1カット分の撮影指示スクリプト
struct ShotScript: Equatable, Identifiable, Sendable {
    let id: String
    /// ボード由来のスレート表記("B1 · 03")。モックスクリプトでは nil
    let slate: String?
    /// メインの撮影指示
    let text: String
    /// 補足のショット指示(text が script のときの shot_direction)
    let direction: String?
    let techniques: [String]
    let reference: ShotReference?

    init(
        id: String,
        slate: String? = nil,
        text: String,
        direction: String? = nil,
        techniques: [String] = [],
        reference: ShotReference? = nil
    ) {
        self.id = id
        self.slate = slate
        self.text = text
        self.direction = direction
        self.techniques = techniques
        self.reference = reference
    }
}

extension [ShotScript] {
    // TODO: ShootCam 単体起動用の固定モック(本体は SBBoard.shotScripts を使う)。
    // モーションコーチの各パターンを確認できるよう動きの語を散らしてある
    static let mock: Self = [
        ShotScript(id: "mock-1", text: "Film the storefront, panning slowly from left to right"),
        ShotScript(id: "mock-2", text: "Whip pan from the street sign to the entrance door"),
        ShotScript(id: "mock-3", text: "Tight overhead shot of your drink on the table"),
        ShotScript(id: "mock-4", text: "Slow push in on the counter as the barista works", direction: "Dolly in smoothly, keep the cup centered"),
        ShotScript(id: "mock-5", text: "Handheld shot follows you to the window seat"),
    ]
}
