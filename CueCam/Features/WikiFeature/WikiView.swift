import ComposableArchitecture
import SwiftUI

struct WikiView: View {
    @Bindable var store: StoreOf<WikiFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            rootList
                .navigationTitle("Wiki")
                .searchable(text: $store.searchQuery, prompt: "ノートを検索")
        } destination: { store in
            switch store.case {
            case .folder(let store):
                WikiFolderView(store: store)
            case .note(let store):
                WikiNoteView(store: store)
            case .tag(let store):
                WikiTagView(store: store)
            }
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private var rootList: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("インデックスを読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
        case .loaded:
            List {
                if !store.searchQuery.isEmpty {
                    searchSection
                } else if let root = store.root {
                    Section("\(store.noteCount) ノート") {
                        FolderRows(folder: root)
                    }
                    if !store.topTags.isEmpty {
                        tagSection
                    }
                }
            }
            .refreshable { await store.send(.refresh).finish() }
        }
    }

    private var searchSection: some View {
        Section("検索結果") {
            if store.searchResults.isEmpty {
                Text("該当なし").foregroundStyle(.secondary)
            }
            ForEach(store.searchResults) { hit in
                NavigationLink(state: WikiFeature.Path.State.note(.init(ref: hit.ref))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.ref.title).font(.body)
                        Text(hit.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
    }

    private var tagSection: some View {
        Section("タグ") {
            FlowTagView(tags: store.topTags)
        }
    }
}

/// フォルダとノートの行(フォルダ直下)。
struct FolderRows: View {
    let folder: FolderNode

    var body: some View {
        ForEach(folder.subfolders) { sub in
            NavigationLink(state: WikiFeature.Path.State.folder(.init(folder: sub))) {
                Label {
                    HStack {
                        Text(sub.name)
                        Spacer()
                        Text("\(sub.notes.count + sub.subfolders.count)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "folder")
                }
            }
        }
        ForEach(folder.notes) { note in
            NavigationLink(state: WikiFeature.Path.State.note(.init(ref: note))) {
                Label(note.title, systemImage: "doc.text")
            }
        }
    }
}

struct WikiFolderView: View {
    let store: StoreOf<WikiFolderFeature>

    var body: some View {
        List {
            FolderRows(folder: store.folder)
        }
        .navigationTitle(store.folder.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WikiTagView: View {
    let store: StoreOf<WikiTagFeature>

    var body: some View {
        List(store.notes) { note in
            NavigationLink(state: WikiFeature.Path.State.note(.init(ref: note))) {
                Label(note.title, systemImage: "doc.text")
            }
        }
        .navigationTitle("#\(store.tag)")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.task) }
    }
}

struct FlowTagView: View {
    let tags: [TagCount]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    NavigationLink(state: WikiFeature.Path.State.tag(.init(tag: tag.tag))) {
                        Text("#\(tag.tag) \(tag.count)")
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
}

struct ErrorRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("読み込みに失敗", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("再試行", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
