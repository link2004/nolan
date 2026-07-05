import Foundation

/// AIディレクターが出す1カット分の撮影指示スクリプト
struct ShotScript: Equatable, Identifiable, Sendable {
    let id: Int
    let text: String
}

extension [ShotScript] {
    // TODO: DirectorClient(Claude API)による動的生成に置き換える
    static let mock: Self = [
        ShotScript(id: 1, text: "お店の外観を正面から、3秒かけてゆっくり撮ってください"),
        ShotScript(id: 2, text: "入口のドアを開けて中に入るシーンを撮ってください"),
        ShotScript(id: 3, text: "店内を左から右へゆっくりパンして全体の雰囲気を撮ってください"),
        ShotScript(id: 4, text: "注文したドリンクを手元のアップで撮ってください"),
        ShotScript(id: 5, text: "窓際の席から外の景色と店内が両方入るように撮ってください"),
    ]
}
