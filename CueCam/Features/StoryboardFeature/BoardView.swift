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
            .toolbarBackground(SBTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .task { store.send(.task) }
            .fullScreenCover(item: $selected) { reference in
                if let url = MediaURL.url(key: reference.path) {
                    FullscreenClipView(url: url, reference: reference)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading board…")
                .tint(SBTheme.fg2)
                .foregroundStyle(SBTheme.fg2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SBTheme.bg)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
                .foregroundStyle(SBTheme.fg2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SBTheme.bg)
        case .loaded:
            if let board = store.board {
                ScrollView {
                    // Webのbeat間隔78pxをモバイル向けに縮めて52pt
                    LazyVStack(alignment: .leading, spacing: 52) {
                        CoverageMeter(coverage: board.coverage)
                        ForEach(board.beats) { beat in
                            BeatSectionView(beat: beat, selected: $selected)
                        }
                    }
                    .padding(.vertical)
                }
                .background(SBTheme.bg)
                .refreshable { await store.send(.refresh).finish() }
            }
        }
    }
}

/// ボード上部のカバレッジメーター(参照が埋まったライン数 / 全ライン数)。
/// Webと同じ「ラベル · トラック · カウント」の1行構成。
struct CoverageMeter: View {
    let coverage: SBCoverage

    /// 表示時にfillを0→ratioへアニメーションさせるためのフラグ(Web側のease-out 0.62sを再現)。
    @State private var appeared = false

    private static let trackWidth: CGFloat = 128

    private var ratio: Double {
        coverage.lines > 0 ? Double(coverage.filled) / Double(coverage.lines) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("COVERAGE")
                .font(.system(size: 10))
                .tracking(1.8)
                .foregroundStyle(SBTheme.fg3)
            Capsule()
                .fill(SBTheme.track)
                .frame(width: Self.trackWidth, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(SBTheme.mark)
                        .frame(width: appeared ? Self.trackWidth * min(max(ratio, 0), 1) : 0)
                }
            Text("\(coverage.filled)/\(coverage.lines) filled")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(SBTheme.fg2)
        }
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeOut(duration: 0.62)) { appeared = true }
        }
    }
}

/// 1 beat分のセクション: 2カラム見出し(番号+timecode / heading+VO) + 横スクロールのカードレール。
struct BeatSectionView: View {
    let beat: SBBeat
    @Binding var selected: SBReference?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    // slate表記(B1 · 03)にライン番号が必要なのでindex付きで回す
                    ForEach(Array(beat.lines.enumerated()), id: \.element.id) { index, line in
                        LineCardView(beatId: beat.id, line: line, lineIndex: index, selected: $selected)
                    }
                }
                .padding(.horizontal)
                // カードのshadowがScrollViewにクリップされないよう余白を確保
                .padding(.bottom, 12)
            }
        }
    }

    /// beat.id("B1"等)から2桁のビート番号("01")を導出する。
    private var beatNumber: String {
        let digits = beat.id.filter(\.isNumber)
        guard let number = Int(digits) else { return beat.id }
        return String(format: "%02d", number)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                // 左カラム: ビート番号 + timecode
                VStack(alignment: .leading, spacing: 4) {
                    Text(beatNumber)
                        .font(.instrumentSerif(38))
                        .foregroundStyle(SBTheme.fg1)
                    if let timecode = beat.timecode, !timecode.isEmpty {
                        Text(timecode)
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(SBTheme.fg3)
                    }
                }
                // 右カラム: heading + VO(英語を本文、日本語を併記。旧データはvoのみのことがある)
                VStack(alignment: .leading, spacing: 8) {
                    if let heading = beat.heading, !heading.isEmpty {
                        Text(heading)
                            .font(.instrumentSerif(26))
                            .tracking(-0.4)
                            .foregroundStyle(SBTheme.fg1)
                    }
                    if let voEn = beat.voEn ?? beat.vo, !voEn.isEmpty {
                        Text(voEn)
                            .font(.instrumentSerif(18))
                            .lineSpacing(2)
                            .foregroundStyle(SBTheme.fg1)
                    }
                    if let voJp = beat.voJp, !voJp.isEmpty {
                        Text(voJp)
                            .font(.instrumentSerif(14))
                            .foregroundStyle(SBTheme.fg2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)
            Rectangle()
                .fill(SBTheme.hairline)
                .frame(height: 1)
        }
    }
}

/// カードレールの1枚。メディア(4:5ポートレート) + スレート/バッジのオーバーレイ + スクリプト + technique。
struct LineCardView: View {
    let beatId: String
    let line: SBLine
    let lineIndex: Int
    @Binding var selected: SBReference?

    private static let cardWidth: CGFloat = 200
    /// Webはメディアが4:5(縦長)。16:9ではないことに注意。
    private static let cardHeight: CGFloat = cardWidth * 5 / 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            media
            details
                .padding(.top, 12)
        }
        .frame(width: Self.cardWidth)
    }

    // MARK: - メディアフレーム

    @ViewBuilder
    private var media: some View {
        if let reference = line.reference,
           let url = MediaURL.url(key: reference.path) {
            filledMedia(reference: reference, url: url)
        } else {
            emptyMedia
        }
    }

    /// 参照ありのメディア: ビネット + スレート + kindバッジ + (クリップなら)再生サークル。
    private func filledMedia(reference: SBReference, url: URL) -> some View {
        Group {
            if reference.isClip {
                InlineClipPlayer(
                    url: url,
                    posterURL: reference.poster.flatMap { MediaURL.url(key: $0) }
                )
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(SBTheme.bgRaised)
                }
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(SBTheme.bgRaised)
        .clipped()
        .overlay { vignette }
        .overlay(alignment: .topLeading) { slate }
        .overlay(alignment: .topTrailing) { kindBadge(reference: reference) }
        .overlay {
            if reference.isClip {
                playCircle
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(SBTheme.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // クリップのみタップでフルスクリーン再生(既存挙動を維持)
            if reference.isClip { selected = reference }
        }
    }

    /// 画面端をわずかに沈める控えめなビネット。
    private var vignette: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.55)],
            center: .center,
            startRadius: Self.cardWidth * 0.4,
            endRadius: Self.cardWidth * 0.95
        )
        .allowsHitTesting(false)
    }

    /// 左上のスレート表記: "B1 · 03"。
    private var slate: some View {
        Text("\(beatId) · \(String(format: "%02d", lineIndex + 1))")
            .font(.system(size: 10, design: .monospaced))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Color.rgb(0xf4f1ea, opacity: 0.6))
            .padding(.top, 11)
            .padding(.leading, 12)
    }

    /// 右上のkindバッジ: CLIP / STILL。
    private func kindBadge(reference: SBReference) -> some View {
        Text(reference.isClip ? "CLIP" : "STILL")
            .font(.system(size: 9))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 11)
            .padding(.trailing, 12)
    }

    /// クリップカード中央の再生サークル(iOSはhoverがないので常時表示)。
    private var playCircle: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(.black.opacity(0.3))
            Image(systemName: "play.fill")
                .font(.system(size: 15))
                .foregroundStyle(SBTheme.fg1)
        }
        .overlay {
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1)
        }
        .frame(width: 44, height: 44)
        .allowsHitTesting(false)
    }

    /// 参照なしの空カード: 破線フレーム + "+"サークル + キャプション。shadowなし。
    private var emptyMedia: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SBTheme.bg)
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(SBTheme.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .overlay {
                VStack(spacing: 12) {
                    Circle()
                        .strokeBorder(SBTheme.hairlineStrong, lineWidth: 1)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundStyle(SBTheme.fg2)
                        }
                    Text("NO REFERENCE YET")
                        .font(.system(size: 10.5))
                        .tracking(1.4)
                        .foregroundStyle(SBTheme.fg3)
                }
            }
    }

    // MARK: - カード本文

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let script = line.script, !script.isEmpty {
                Text(script)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(SBTheme.fg1)
                    .lineLimit(3)
            }
            if let scriptJp = line.scriptJp, !scriptJp.isEmpty {
                Text(scriptJp)
                    .font(.system(size: 12))
                    .foregroundStyle(SBTheme.fg2)
                    .lineLimit(3)
            }
            HStack(spacing: 6) {
                if let timecode = line.timecode, !timecode.isEmpty {
                    Text(timecode)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SBTheme.fg3)
                }
                ForEach(line.technique ?? [], id: \.self) { technique in
                    TechniqueTag(text: technique)
                }
            }
        }
    }
}

/// techniqueチップ: ヘアライン枠のみの透明カプセル。
struct TechniqueTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(SBTheme.fg2)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay {
                Capsule().strokeBorder(SBTheme.hairline, lineWidth: 1)
            }
    }
}
