import ComposableArchitecture
import SwiftUI

struct ProjectsView: View {
    @Bindable var store: StoreOf<ProjectsFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            rootList
                .navigationTitle("Storyboard")
        } destination: { store in
            BoardView(store: store)
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private var rootList: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("プロジェクトを読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
        case .loaded:
            List(store.projects) { project in
                if project.hasStoryboard == false {
                    // ストーリーボード未作成のプロジェクトは遷移不可
                    ProjectRow(project: project, base: store.base)
                        .opacity(0.4)
                } else {
                    NavigationLink(state: BoardFeature.State(note: project.note, title: project.title)) {
                        ProjectRow(project: project, base: store.base)
                    }
                }
            }
            .refreshable { await store.send(.refresh).finish() }
        }
    }
}

/// プロジェクト一覧の1行。サムネイル + タイトル + client/statusバッジ + カバレッジバー。
struct ProjectRow: View {
    let project: SBProject
    let base: URL?

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let client = project.client, !client.isEmpty {
                        BadgeText(client, tint: .blue)
                    }
                    if let status = project.status, !status.isEmpty {
                        BadgeText(status, tint: .orange)
                    }
                }
                if let coverage = project.coverage {
                    ProgressView(value: min(max(coverage, 0), 1))
                        .tint(coverage >= 1 ? .green : .accentColor)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        let url = base.flatMap { base in
            project.thumbnail.flatMap { MediaURL.url(base: base, key: $0) }
        }
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.tertiary)
                }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// client/status用の小さなバッジ。
struct BadgeText: View {
    let text: String
    let tint: Color

    init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
