import AVFoundation
import SwiftUI

/// カード内のミュートループ再生プレーヤー。
/// ポスター(AsyncImage)を敷き、スクロールで50%以上可視になったら再生を開始し、
/// 不可視/画面離脱で即座に停止・破棄する。同時再生数はPlayerPoolで制限する。
struct InlineClipPlayer: View {
    let url: URL
    let posterURL: URL?

    @State private var model = InlineClipModel()

    init(url: URL, posterURL: URL?) {
        self.url = url
        self.posterURL = posterURL
    }

    var body: some View {
        ZStack {
            AsyncImage(url: posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            if let player = model.player {
                PlayerLayerView(player: player)
            }
        }
        .onScrollVisibilityChange(threshold: 0.5) { visible in
            if visible {
                model.play(url: url)
            } else {
                model.stop()
            }
        }
        .onDisappear { model.stop() }
    }
}

/// 1カード分のプレーヤー状態。AVPlayerLooperでシームレスにループさせる。
/// PlayerPoolから強制停止されることがあるため、停止経路を一本化している。
@MainActor
@Observable
final class InlineClipModel {
    private(set) var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func play(url: URL) {
        guard player == nil else { return }
        PlayerPool.shared.willPlay(self)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        // R2への302リダイレクトはAVPlayerが自動追従する
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        queue.play()
        player = queue
    }

    func stop() {
        teardown()
        PlayerPool.shared.didStop(self)
    }

    /// プール側からの強制停止(プール登録は呼び出し元が整理済み)。
    fileprivate func stopFromPool() {
        teardown()
    }

    private func teardown() {
        player?.pause()
        looper = nil
        player = nil
    }
}

/// 同時再生数の上限管理(LRU)。ボードのレールを高速スクロールしたとき、
/// デコーダを食い潰さないよう最大4本まで。超過時は最も古い再生を止める。
@MainActor
final class PlayerPool {
    static let shared = PlayerPool()
    private static let maxConcurrent = 4

    /// 古い順に並ぶ再生中モデル(弱参照で保持リークを防ぐ)。
    private var active: [Weak] = []

    private struct Weak {
        weak var model: InlineClipModel?
    }

    /// 再生開始前に呼ぶ。枠が埋まっていれば最古のプレーヤーを停止して枠を空ける。
    func willPlay(_ model: InlineClipModel) {
        active.removeAll { $0.model == nil || $0.model === model }
        while active.count >= Self.maxConcurrent {
            active.removeFirst().model?.stopFromPool()
        }
        active.append(Weak(model: model))
    }

    func didStop(_ model: InlineClipModel) {
        active.removeAll { $0.model == nil || $0.model === model }
    }
}
