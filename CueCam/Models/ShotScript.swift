import Foundation

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

    init(
        id: String,
        slate: String? = nil,
        text: String,
        direction: String? = nil,
        techniques: [String] = []
    ) {
        self.id = id
        self.slate = slate
        self.text = text
        self.direction = direction
        self.techniques = techniques
    }
}

extension [ShotScript] {
    // TODO: ShootCam 単体起動用の固定モック(本体は SBBoard.shotScripts を使う)
    static let mock: Self = [
        ShotScript(id: "mock-1", text: "Film the storefront from the front, panning slowly for about 3 seconds"),
        ShotScript(id: "mock-2", text: "Film yourself opening the door and walking inside"),
        ShotScript(id: "mock-3", text: "Slowly pan from left to right to capture the atmosphere of the interior"),
        ShotScript(id: "mock-4", text: "Film a close-up of the drink you ordered"),
        ShotScript(id: "mock-5", text: "From a window seat, frame both the view outside and the interior"),
    ]
}
