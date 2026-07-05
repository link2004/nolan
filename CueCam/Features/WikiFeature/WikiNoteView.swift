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
                                    NavigationLink(state: WikiFeature.Path.State.tag(.init(tag: tag))) {
                                        WikiTagChip(text: "#\(tag)", palette: palette)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // 本文: サイトの 1.02rem / 1.72行間 に相当。
                    Text(note.content)
                        .font(.system(size: 16))
                        .lineSpacing(7)
                        .foregroundStyle(palette.dark)
                        .textSelection(.enabled)

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
                    NavigationLink(state: WikiFeature.Path.State.note(.init(ref: ref))) {
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
