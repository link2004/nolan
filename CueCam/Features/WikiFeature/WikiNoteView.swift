import ComposableArchitecture
import SwiftUI

struct WikiNoteView: View {
    let store: StoreOf<WikiNoteFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.title)
                    .font(.title.bold())

                if let note = store.note {
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.tags, id: \.self) { tag in
                                    NavigationLink(state: WikiFeature.Path.State.tag(.init(tag: tag))) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text(note.content)
                        .font(.body)
                        .textSelection(.enabled)

                    linkList("リンク", refs: store.outgoing, icon: "arrow.up.right")
                    linkList("バックリンク", refs: store.backlinks, icon: "arrow.uturn.backward")
                } else if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    Text("ノートが見つかりません")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.task) }
    }

    @ViewBuilder
    private func linkList(_ title: String, refs: [WikiNoteRef], icon: String) -> some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .padding(.top, 8)
                ForEach(refs) { ref in
                    NavigationLink(state: WikiFeature.Path.State.note(.init(ref: ref))) {
                        Label(ref.title, systemImage: icon)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
