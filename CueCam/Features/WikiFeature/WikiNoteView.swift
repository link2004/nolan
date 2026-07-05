import ComposableArchitecture
import SwiftUI

struct WikiNoteView: View {
    let store: StoreOf<WikiNoteFeature>
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // サイトの記事見出し(Instrument Serif、詰めたトラッキング)を再現。
                Text(store.title)
                    .font(.instrumentSerif(30))
                    .kerning(-0.3)
                    .lineSpacing(2)
                    .foregroundStyle(palette.dark)

                if let note = store.note {
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.tags, id: \.self) { tag in
                                    NavigationLink(state: AppReducer.Path.State.tag(.init(tag: tag))) {
                                        WikiTagChip(text: "#\(tag)", palette: palette)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // 本文はそのまま保ち、各クリップの見出し直後に動画プレーヤーを差し込む
                    // (見出し・引用のテキストはplaintext本文に既に含まれる)。
                    ForEach(WikiNoteBody.blocks(content: note.content, clips: store.clips)) { block in
                        switch block.kind {
                        case .text(let text):
                            // 本文: サイトの 1.02rem / 1.72行間 に相当。
                            Text(text)
                                .font(.system(size: 16))
                                .lineSpacing(7)
                                .foregroundStyle(palette.dark)
                                .textSelection(.enabled)
                        case .clip(let clip):
                            // InlineClipPlayer はミュートループでスクロール可視時に自動再生(web挙動と一致)。
                            InlineClipPlayer(url: clip.url, posterURL: nil)
                                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    linkList("Links", refs: store.outgoing, icon: "arrow.up.right")
                    linkList("Backlinks", refs: store.backlinks, icon: "arrow.uturn.backward")
                } else if store.isLoading {
                    ProgressView()
                        .tint(palette.darkgray)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    Text("Note not found")
                        .foregroundStyle(palette.darkgray)
                }
            }
            .padding()
            // サイト同様の可読幅に収め、広い画面では中央寄せにする。
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(palette.light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.light, for: .navigationBar)
        .task { store.send(.task) }
    }

    @ViewBuilder
    private func linkList(_ title: String, refs: [WikiNoteRef], icon: String) -> some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                WikiRailLabel(text: title, palette: palette)
                    .padding(.top, 8)
                ForEach(refs) { ref in
                    NavigationLink(state: AppReducer.Path.State.note(.init(ref: ref))) {
                        // サイトの内部リンク: 静かなグレー下線(hover緑はiOSでは省略)。
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                                .foregroundStyle(palette.gray)
                            Text(ref.title)
                                .font(.system(size: 15))
                                .underline(true, color: palette.gray.opacity(0.55))
                                .foregroundStyle(palette.dark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// plaintext本文に動画プレーヤーを差し込むためのブロック列を組み立てる。
/// クリップの見出し(source。例 "Foo · 0:08 ↗")はplaintext本文にそのまま現れるので、
/// それをアンカーに動画をその直後へ挿入する。マーカー文字列に依存せず、動画セクションが
/// 本文の途中(後ろにTranscript等が続く)にあっても正しく差し込める。
enum WikiNoteBody {
    struct Block: Identifiable {
        enum Kind {
            case text(String)
            case clip(WikiClip)
        }
        let id: Int
        let kind: Kind
    }

    static func blocks(content: String, clips: [WikiClip]) -> [Block] {
        guard !clips.isEmpty else {
            return content.isEmpty ? [] : [Block(id: 0, kind: .text(content))]
        }

        var blocks: [Block] = []
        var next = 0
        func addText(_ s: Substring) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            blocks.append(Block(id: next, kind: .text(trimmed)))
            next += 1
        }

        var cursor = content.startIndex
        for clip in clips {
            // 見出しの直後に動画を差し込む。見出しが取れない/本文に無い場合は動画だけ追加。
            if let source = clip.source,
               let range = content.range(of: source, range: cursor..<content.endIndex) {
                addText(content[cursor..<range.upperBound])
                cursor = range.upperBound
            }
            blocks.append(Block(id: next, kind: .clip(clip)))
            next += 1
        }
        addText(content[cursor...])
        return blocks
    }
}
