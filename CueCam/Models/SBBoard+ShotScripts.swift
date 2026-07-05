import Foundation

// ShotScript.swift ではなくこのファイルに置くことで、StoryboardModels を含まない
// ShootCam ターゲットから SBBoard への依存を切り離している(ADR-004)

extension SBBoard {
    /// beats × lines を撮影順のスクリプトへ平坦化する(全ライン対象)。
    /// メイン指示は script → shot_direction → beat.heading の順でフォールバックし、
    /// どれも無いラインはスキップする
    var shotScripts: [ShotScript] {
        beats.flatMap { beat in
            beat.lines.enumerated().compactMap { index, line -> ShotScript? in
                let script = line.script?.trimmingCharacters(in: .whitespacesAndNewlines)
                let direction = line.shotDirection?.trimmingCharacters(in: .whitespacesAndNewlines)
                let heading = beat.heading?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let text = [script, direction, heading]
                    .compactMap({ $0 })
                    .first(where: { !$0.isEmpty })
                else { return nil }
                return ShotScript(
                    // line.id のボード全体での一意性に依存しないよう beat.id と合成する
                    id: "\(beat.id)/\(line.id)",
                    slate: "\(beat.id) · \(String(format: "%02d", index + 1))",
                    text: text,
                    direction: (direction?.isEmpty == false && direction != text) ? direction : nil,
                    techniques: line.technique ?? [],
                    reference: line.reference.flatMap { reference in
                        MediaURL.url(key: reference.path).map { url in
                            ShotReference(
                                isClip: reference.isClip,
                                url: url,
                                posterURL: reference.poster.flatMap { MediaURL.url(key: $0) }
                            )
                        }
                    }
                )
            }
        }
    }
}
