import ComposableArchitecture
import SwiftUI

// MARK: - Quartzテーマ共通スタイル(WikiFeature内で共有)

/// サイトのレール見出し("611 NOTES" / "TAGS"等)を再現したセクションラベル。
struct WikiRailLabel: View {
    let text: String
    let palette: WikiPalette

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .textCase(.uppercase)
            .foregroundStyle(palette.gray)
    }
}

/// サイトのタグ表示を再現した静かなアウトラインチップ(塗りつぶしピルにしない)。
struct WikiTagChip: View {
    let text: String
    let palette: WikiPalette

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(palette.darkgray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(palette.lightgray, lineWidth: 1)
            )
    }
}

// MARK: - ルート画面

struct WikiView: View {
    @Bindable var store: StoreOf<WikiFeature>
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        // タブ廃止に伴い、Wikiルートはホームのスタックに積まれる1画面になった
        rootList
            .navigationTitle("Wiki")
            .searchable(text: $store.searchQuery, prompt: "Search notes")
            .toolbarBackground(palette.light, for: .navigationBar)
            .task { store.send(.task) }
    }

    @ViewBuilder
    private var rootList: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading index…")
                .tint(palette.darkgray)
                .foregroundStyle(palette.darkgray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.light)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.light)
        case .loaded:
            List {
                if !store.searchQuery.isEmpty {
                    searchSection
                } else if let root = store.root {
                    Section {
                        FolderRows(folder: root)
                    } header: {
                        WikiRailLabel(text: "\(store.noteCount) notes", palette: palette)
                    }
                    if !store.topTags.isEmpty {
                        tagSection
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(palette.light)
            .refreshable { await store.send(.refresh).finish() }
        }
    }

    private var searchSection: some View {
        Section {
            if store.searchResults.isEmpty {
                Text("No matches")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.darkgray)
                    .listRowBackground(Color.clear)
            }
            ForEach(store.searchResults) { hit in
                NavigationLink(state: AppReducer.Path.State.note(.init(ref: hit.ref))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.ref.title)
                            .font(.system(size: 16))
                            .foregroundStyle(palette.dark)
                        Text(hit.snippet)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.darkgray)
                            .lineLimit(2)
                    }
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            WikiRailLabel(text: "Results", palette: palette)
        }
    }

    private var tagSection: some View {
        Section {
            FlowTagView(tags: store.topTags)
                .listRowBackground(Color.clear)
        } header: {
            WikiRailLabel(text: "Tags", palette: palette)
        }
    }
}

/// フォルダとノートの行(フォルダ直下)。
struct FolderRows: View {
    let folder: FolderNode
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        ForEach(folder.subfolders) { sub in
            NavigationLink(state: AppReducer.Path.State.folder(.init(folder: sub))) {
                Label {
                    HStack {
                        Text(sub.name)
                            .font(.system(size: 16))
                            .foregroundStyle(palette.dark)
                        Spacer()
                        Text("\(sub.notes.count + sub.subfolders.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.gray)
                    }
                } icon: {
                    Image(systemName: "folder")
                        .foregroundStyle(palette.gray)
                }
            }
            .listRowBackground(Color.clear)
        }
        ForEach(folder.notes) { note in
            NavigationLink(state: AppReducer.Path.State.note(.init(ref: note))) {
                Label {
                    Text(note.title)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.dark)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(palette.gray)
                }
            }
            .listRowBackground(Color.clear)
        }
    }
}

struct WikiFolderView: View {
    let store: StoreOf<WikiFolderFeature>
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        List {
            FolderRows(folder: store.folder)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(palette.light)
        .navigationTitle(store.folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.light, for: .navigationBar)
    }
}

struct WikiTagView: View {
    let store: StoreOf<WikiTagFeature>
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        List(store.notes) { note in
            NavigationLink(state: AppReducer.Path.State.note(.init(ref: note))) {
                Label {
                    Text(note.title)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.dark)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(palette.gray)
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(palette.light)
        .navigationTitle("#\(store.tag)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.light, for: .navigationBar)
        .task { store.send(.task) }
    }
}

struct FlowTagView: View {
    let tags: [TagCount]
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WikiPalette { .current(colorScheme) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    NavigationLink(state: AppReducer.Path.State.tag(.init(tag: tag.tag))) {
                        WikiTagChip(text: "#\(tag.tag) \(tag.count)", palette: palette)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 他Featureと共有のエラー表示。API(message:retry:)は維持し、内部はニュートラルに整える。
struct ErrorRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Failed to load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
                .foregroundStyle(.secondary)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
    }
}
