import ComposableArchitecture
import SwiftUI

struct BoardView: View {
    let store: StoreOf<BoardFeature>

    /// フルスクリーン再生中のクリップ参照(ビューローカルな一時状態なのでStateに持たない)。
    @State private var selected: SBReference?

    var body: some View {
        content
            .navigationTitle(store.board?.title ?? store.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { store.send(.task) }
            .fullScreenCover(item: $selected) { reference in
                if let base = store.base,
                   let url = MediaURL.url(base: base, key: reference.path) {
                    FullscreenClipView(url: url, reference: reference)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("ボードを読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
        case .loaded:
            if let board = store.board {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        CoverageMeter(coverage: board.coverage)
                        ForEach(board.beats) { beat in
                            BeatSectionView(beat: beat, base: store.base, selected: $selected)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable { await store.send(.refresh).finish() }
            }
        }
    }
}

/// ボード上部のカバレッジメーター(参照が埋まったライン数 / 全ライン数)。
struct CoverageMeter: View {
    let coverage: SBCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("カバレッジ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(coverage.filled) / \(coverage.lines)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: coverage.lines > 0 ? Double(coverage.filled) / Double(coverage.lines) : 0)
                .tint(coverage.empty == 0 ? .green : .accentColor)
        }
        .padding(.horizontal)
    }
}

/// 1 beat分のセクション: 見出し(番号・timecode・heading・VO) + 横スクロールのカードレール。
struct BeatSectionView: View {
    let beat: SBBeat
    let base: URL?
    @Binding var selected: SBReference?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(beat.lines) { line in
                        LineCardView(line: line, base: base, selected: $selected)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(beat.id)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                if let timecode = beat.timecode, !timecode.isEmpty {
                    Text(timecode)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let heading = beat.heading, !heading.isEmpty {
                Text(heading)
                    .font(.headline)
            }
            // VOは英語を本文、日本語をセカンダリで併記(旧データはvoのみのことがある)
            if let voEn = beat.voEn ?? beat.vo, !voEn.isEmpty {
                Text(voEn)
                    .font(.subheadline)
            }
            if let voJp = beat.voJp, !voJp.isEmpty {
                Text(voJp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// カードレールの1枚。メディア(16:9) + スクリプト + timecode + techniqueチップ。
struct LineCardView: View {
    let line: SBLine
    let base: URL?
    @Binding var selected: SBReference?

    private static let cardWidth: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            media
                .frame(width: Self.cardWidth, height: Self.cardWidth * 9 / 16)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            details
        }
        .frame(width: Self.cardWidth)
    }

    @ViewBuilder
    private var media: some View {
        if let reference = line.reference, let base,
           let url = MediaURL.url(base: base, key: reference.path) {
            if reference.isClip {
                InlineClipPlayer(
                    url: url,
                    posterURL: reference.poster.flatMap { MediaURL.url(base: base, key: $0) }
                )
                .contentShape(Rectangle())
                .onTapGesture { selected = reference }
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.tertiary)
                .overlay {
                    Text("参照未設定")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let script = line.script, !script.isEmpty {
                Text(script)
                    .font(.caption)
                    .lineLimit(3)
            }
            if let scriptJp = line.scriptJp, !scriptJp.isEmpty {
                Text(scriptJp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack(spacing: 6) {
                if let timecode = line.timecode, !timecode.isEmpty {
                    Text(timecode)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                ForEach(line.technique ?? [], id: \.self) { technique in
                    Text(technique)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
