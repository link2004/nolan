import Foundation

/// AIディレクターが生成する1カット分の撮影指示
struct ShotInstruction: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    /// カットの名前（例: 「オープニング: 全体を見せる」）
    var title: String
    /// 何をどう撮るかの具体的な指示（例: 「引きの構図で全体をゆっくり左から右へパン」）
    var direction: String
    /// 推奨撮影秒数
    var durationSeconds: Int

    init(id: UUID = UUID(), title: String, direction: String, durationSeconds: Int) {
        self.id = id
        self.title = title
        self.direction = direction
        self.durationSeconds = durationSeconds
    }
}
