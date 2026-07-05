import ComposableArchitecture
import Foundation

@Reducer
struct WikiFeature {
    @Reducer(state: .equatable)
    enum Path {
        case folder(WikiFolderFeature)
        case note(WikiNoteFeature)
        case tag(WikiTagFeature)
    }

    @ObservableState
    struct State: Equatable {
        var loadState: LoadState = .idle
        var root: FolderNode?
        var noteCount = 0
        var topTags: [TagCount] = []
        var searchQuery = ""
        var searchResults: [WikiSearchHit] = []
        var path = StackState<Path.State>()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case refresh
        case summaryLoaded(Result<WikiSummary, any Error>)
        case searchResponse([WikiSearchHit])
        case path(StackActionOf<Path>)
    }

    @Dependency(\.wikiClient) var wikiClient
    @Dependency(\.serverConfig) var serverConfig

    private enum CancelID { case search }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                let query = state.searchQuery
                guard query.trimmingCharacters(in: .whitespaces).count >= 2 else {
                    state.searchResults = []
                    return .cancel(id: CancelID.search)
                }
                return .run { send in
                    try await Task.sleep(for: .milliseconds(250))
                    await send(.searchResponse(wikiClient.search(query)))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .binding:
                return .none

            case .task:
                guard state.loadState == .idle || state.loadState.isFailure else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case .summaryLoaded(.success(let summary)):
                state.loadState = .loaded
                state.root = summary.root
                state.noteCount = summary.noteCount
                state.topTags = Array(summary.tags.prefix(30))
                return .none

            case .summaryLoaded(.failure(let error)):
                state.loadState = .failed(error.localizedDescription)
                return .none

            case .searchResponse(let hits):
                state.searchResults = hits
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.loadState = .loading
        return .run { send in
            await send(.summaryLoaded(Result {
                try await wikiClient.load(serverConfig.baseURL(.wiki))
            }))
        }
    }
}

extension LoadState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// フォルダ画面は純粋なデータ表示(遷移はNavigationLink(state:))。
@Reducer
struct WikiFolderFeature {
    @ObservableState
    struct State: Equatable {
        let folder: FolderNode
    }
    enum Action {}
    var body: some ReducerOf<Self> { EmptyReducer() }
}

@Reducer
struct WikiNoteFeature {
    @ObservableState
    struct State: Equatable {
        let slug: String
        let title: String
        var note: WikiNote?
        var outgoing: [WikiNoteRef] = []
        var backlinks: [WikiNoteRef] = []
        var isLoading = true

        init(ref: WikiNoteRef) {
            self.slug = ref.slug
            self.title = ref.title
        }
    }

    enum Action {
        case task
        case loaded(WikiNote?, outgoing: [WikiNoteRef], backlinks: [WikiNoteRef])
    }

    @Dependency(\.wikiClient) var wikiClient
    @Dependency(\.serverConfig) var serverConfig

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.note == nil else { return .none }
                let slug = state.slug
                return .run { send in
                    // マップ等からWikiタブを経ずに直行した場合、インデックスがまだ無い
                    if let base = try? serverConfig.baseURL(.wiki) {
                        try? await wikiClient.ensureLoaded(base)
                    }
                    var note = await wikiClient.note(slug)
                    // slugの綴りずれ(エンコード差など)は末尾コンポーネントで再解決
                    if note == nil, let last = slug.split(separator: "/").last,
                       let ref = await wikiClient.resolveLink(String(last)) {
                        note = await wikiClient.note(ref.slug)
                    }
                    let resolvedSlug = note?.slug ?? slug
                    var outgoing: [WikiNoteRef] = []
                    for link in note?.links ?? [] {
                        if let ref = await wikiClient.resolveLink(link), ref.slug != resolvedSlug,
                           !outgoing.contains(ref) {
                            outgoing.append(ref)
                        }
                    }
                    let backlinks = await wikiClient.backlinks(resolvedSlug)
                    await send(.loaded(note, outgoing: outgoing, backlinks: backlinks))
                }

            case .loaded(let note, let outgoing, let backlinks):
                state.note = note
                state.outgoing = outgoing
                state.backlinks = backlinks
                state.isLoading = false
                return .none
            }
        }
    }
}

@Reducer
struct WikiTagFeature {
    @ObservableState
    struct State: Equatable {
        let tag: String
        var notes: [WikiNoteRef] = []
    }

    enum Action {
        case task
        case loaded([WikiNoteRef])
    }

    @Dependency(\.wikiClient) var wikiClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let tag = state.tag
                return .run { send in
                    await send(.loaded(wikiClient.notesForTag(tag)))
                }
            case .loaded(let notes):
                state.notes = notes
                return .none
            }
        }
    }
}
