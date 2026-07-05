import ComposableArchitecture
import Foundation

/// テーマから撮影指示（ショットリスト）を生成するAIディレクター
@DependencyClient
struct DirectorClient {
    /// テーマ（例: 「カフェの紹介動画」）を渡すと撮影すべきカットのリストを返す
    var makeShotPlan: @Sendable (_ theme: String) async throws -> [ShotInstruction]
}

extension DirectorClient: DependencyKey {
    // TODO: Claude APIでテーマに応じたショットリストを動的生成する。現状は固定モック
    static let liveValue = DirectorClient(
        makeShotPlan: { theme in
            [
                ShotInstruction(
                    title: "オープニング: 全体を見せる",
                    direction: "「\(theme)」の全体がわかる引きの構図で、左から右へゆっくりパンしてください",
                    durationSeconds: 8
                ),
                ShotInstruction(
                    title: "主役のクローズアップ",
                    direction: "一番見せたい被写体に近づき、正面からじっくり映してください",
                    durationSeconds: 6
                ),
                ShotInstruction(
                    title: "ディテール",
                    direction: "手元や質感など、細部が伝わる寄りのカットを撮ってください",
                    durationSeconds: 5
                ),
                ShotInstruction(
                    title: "エンディング",
                    direction: "被写体からゆっくり遠ざかりながら、締めのカットを撮ってください",
                    durationSeconds: 6
                ),
            ]
        }
    )

    static let testValue = DirectorClient()
}

extension DependencyValues {
    var directorClient: DirectorClient {
        get { self[DirectorClient.self] }
        set { self[DirectorClient.self] = newValue }
    }
}
