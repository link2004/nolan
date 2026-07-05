import ComposableArchitecture
import SwiftUI

struct ProjectsView: View {
    @Bindable var store: StoreOf<ProjectsFeature>

    var body: some View {
        // タブ廃止に伴い、ホームのスタックに積まれる1画面になった(ボードはさらに上へ積む)
        rootList
            .navigationTitle("Storyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }  // 大見出しは自前のセリフ wordmark に置き換える
            .toolbarBackground(SBTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)  // 常時ダークなシネマ面。ライト端末でも chrome を正しく描く
            .task { store.send(.task) }
    }

    @ViewBuilder
    private var rootList: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading projects…")
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
            List {
                header
                ForEach(store.projects) { project in
                    Group {
                        if project.hasStoryboard == false {
                            // ストーリーボード未作成のプロジェクトは遷移不可
                            ProjectRow(project: project)
                                .opacity(0.4)
                        } else {
                            NavigationLink(state: AppReducer.Path.State.board(BoardFeature.State(note: project.note, title: project.title))) {
                                ProjectRow(project: project)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(SBTheme.hairline)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 20 }  // サムネ幅ぶんインセットせず、テキスト頭に揃える
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SBTheme.bg)
            .refreshable { await store.send(.refresh).finish() }
        }
    }

    /// 本文と同じ Instrument Serif のセリフ wordmark。システム大見出し(SF・ダーク端末で不可視)を置き換える。
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Storyboard")
                .font(.instrumentSerif(40))
                .foregroundStyle(SBTheme.fg1)
            Text("\(store.projects.count) projects")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.5)
                .textCase(.uppercase)
                .foregroundStyle(SBTheme.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 10, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

/// プロジェクト一覧の1行。サムネイル + タイトル + client/statusピル + カバレッジバー。
struct ProjectRow: View {
    let project: SBProject

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.instrumentSerif(19))
                    .foregroundStyle(SBTheme.fg1)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let client = project.client, !client.isEmpty {
                        // clientはニュートラルなヘアライン枠ピル
                        StatusPill(text: client, background: .clear, foreground: SBTheme.fg2, bordered: true)
                    }
                    if let status = project.status, !status.isEmpty {
                        let tint = StatusPill.tint(for: status)
                        StatusPill(text: status, background: tint.background, foreground: tint.foreground)
                    }
                }
                if let coverage = project.coverage {
                    CoverageBar(ratio: coverage)
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        let url = project.thumbnail.flatMap { MediaURL.url(key: $0) }
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(SBTheme.bgRaised)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(SBTheme.fg3)
                }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(SBTheme.hairline, lineWidth: 1)
        }
    }
}

/// client/status用のステータスピル。statusは状態に応じてgreen/crimson/amberに色分けする。
struct StatusPill: View {
    let text: String
    let background: Color
    let foreground: Color
    var bordered: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .overlay {
                if bordered {
                    Capsule().strokeBorder(SBTheme.hairline, lineWidth: 1)
                }
            }
    }

    /// statusの状態 → ピルの配色。refined=green / generating・failed=crimson / それ以外=amber。
    static func tint(for status: String) -> (background: Color, foreground: Color) {
        switch status.lowercased() {
        case "refined":
            return (SBTheme.greenBg, SBTheme.greenText)
        case "generating", "failed":
            return (SBTheme.crimson.opacity(0.18), Color.rgb(0xe4bcbc))
        default:
            return (SBTheme.amberBg, SBTheme.amberText)
        }
    }
}

/// カバレッジバー(ダークなトラック + markのfill)。
struct CoverageBar: View {
    let ratio: Double

    var body: some View {
        Capsule()
            .fill(SBTheme.track)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(SBTheme.mark)
                        .frame(width: proxy.size.width * min(max(ratio, 0), 1))
                }
            }
    }
}
