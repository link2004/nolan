import ComposableArchitecture
import Foundation

/// contentIndex.json(~3MB)を保持・検索するactor。生マップはTCA Stateに載せず、
/// ここからWikiNoteRef等の軽量データだけを返す。
actor WikiIndexStore {
    static let shared = WikiIndexStore()

    private var notes: [String: WikiNote] = [:]
    private var backlinksMap: [String: [String]] = [:]
    private var tagMap: [String: [String]] = [:]

    func load(base: URL) async throws -> WikiSummary {
        guard let url = URL(string: "/static/contentIndex.json", relativeTo: base)?.absoluteURL else {
            throw HTTPError.invalidURL(base.absoluteString)
        }
        let raw: [String: WikiIndexEntry] = try await HTTP.getJSON(url)

        var built: [String: WikiNote] = [:]
        built.reserveCapacity(raw.count)
        for (slug, entry) in raw {
            built[slug] = WikiNote(
                slug: slug,
                title: Self.decodeEntities(entry.title ?? slug),
                content: Self.decodeEntities(entry.content ?? ""),
                links: entry.links ?? [],
                tags: entry.tags ?? []
            )
        }
        notes = built

        // links はSimpleSlug。完全一致 → 末尾コンポーネント一致の順で解決して逆リンクを張る。
        var lastComponent: [String: [String]] = [:]
        for slug in built.keys {
            let last = slug.split(separator: "/").last.map(String.init) ?? slug
            lastComponent[last, default: []].append(slug)
        }
        var back: [String: [String]] = [:]
        for (slug, note) in built {
            for link in note.links {
                let target: String?
                if built[link] != nil {
                    target = link
                } else {
                    target = lastComponent[link]?.first
                }
                if let target, target != slug {
                    back[target, default: []].append(slug)
                }
            }
        }
        backlinksMap = back

        var tags: [String: [String]] = [:]
        for (slug, note) in built {
            for tag in note.tags { tags[tag, default: []].append(slug) }
        }
        tagMap = tags

        return WikiSummary(
            root: buildTree(),
            noteCount: built.count,
            tags: tags.map { TagCount(tag: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
        )
    }

    /// インデックス未ロード時だけロードする(マップ→ノート直行など、Wikiタブを経ない導線用)。
    func ensureLoaded(base: URL) async throws {
        if notes.isEmpty {
            _ = try await load(base: base)
        }
    }

    func note(slug: String) -> WikiNote? { notes[slug] }

    func resolve(link: String) -> WikiNoteRef? {
        if let n = notes[link] { return WikiNoteRef(slug: n.slug, title: n.title) }
        let match = notes.values.first { $0.slug.split(separator: "/").last.map(String.init) == link }
        return match.map { WikiNoteRef(slug: $0.slug, title: $0.title) }
    }

    func backlinks(slug: String) -> [WikiNoteRef] {
        (backlinksMap[slug] ?? [])
            .compactMap { notes[$0] }
            .map { WikiNoteRef(slug: $0.slug, title: $0.title) }
            .sorted { $0.title < $1.title }
    }

    func notes(tag: String) -> [WikiNoteRef] {
        (tagMap[tag] ?? [])
            .compactMap { notes[$0] }
            .map { WikiNoteRef(slug: $0.slug, title: $0.title) }
            .sorted { $0.title < $1.title }
    }

    func search(_ query: String, limit: Int = 40) -> [WikiSearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var titleHits: [WikiSearchHit] = []
        var contentHits: [WikiSearchHit] = []
        for note in notes.values {
            if note.title.lowercased().contains(q) {
                titleHits.append(WikiSearchHit(
                    ref: WikiNoteRef(slug: note.slug, title: note.title),
                    snippet: Self.snippet(of: note.content, around: q) ?? String(note.content.prefix(120))
                ))
            } else if let snip = Self.snippet(of: note.content, around: q) {
                contentHits.append(WikiSearchHit(
                    ref: WikiNoteRef(slug: note.slug, title: note.title),
                    snippet: snip
                ))
            }
            if titleHits.count >= limit { break }
        }
        titleHits.sort { $0.ref.title < $1.ref.title }
        contentHits.sort { $0.ref.title < $1.ref.title }
        return Array((titleHits + contentHits).prefix(limit))
    }

    // MARK: - helpers

    private func buildTree() -> FolderNode {
        var folders: [String: (subpaths: Set<String>, notes: [WikiNoteRef])] = ["": ([], [])]
        for note in notes.values {
            let parts = note.slug.split(separator: "/").map(String.init)
            let ref = WikiNoteRef(slug: note.slug, title: note.title)
            let dir = parts.dropLast().joined(separator: "/")
            var path = ""
            for part in parts.dropLast() {
                let child = path.isEmpty ? part : "\(path)/\(part)"
                folders[path, default: ([], [])].subpaths.insert(child)
                if folders[child] == nil { folders[child] = ([], []) }
                path = child
            }
            folders[dir, default: ([], [])].notes.append(ref)
        }

        func node(_ path: String) -> FolderNode {
            let entry = folders[path] ?? ([], [])
            return FolderNode(
                path: path,
                name: path.split(separator: "/").last.map(String.init) ?? "Vault",
                subfolders: entry.subpaths.sorted().map(node),
                notes: entry.notes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )
        }
        return node("")
    }

    private static func snippet(of content: String, around query: String, radius: Int = 60) -> String? {
        guard let range = content.range(of: query, options: [.caseInsensitive]) else { return nil }
        let start = content.index(range.lowerBound, offsetBy: -radius, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: radius, limitedBy: content.endIndex) ?? content.endIndex
        let prefix = start > content.startIndex ? "…" : ""
        let suffix = end < content.endIndex ? "…" : ""
        return prefix + content[start..<end].replacingOccurrences(of: "\n", with: " ") + suffix
    }

    /// contentIndexのplaintextに残るHTMLエンティティの最小復号。
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        return out
    }
}

@DependencyClient
struct WikiClient {
    var load: @Sendable (_ base: URL) async throws -> WikiSummary
    var ensureLoaded: @Sendable (_ base: URL) async throws -> Void
    var note: @Sendable (_ slug: String) async -> WikiNote?
    var resolveLink: @Sendable (_ link: String) async -> WikiNoteRef?
    var backlinks: @Sendable (_ slug: String) async -> [WikiNoteRef] = { _ in [] }
    var notesForTag: @Sendable (_ tag: String) async -> [WikiNoteRef] = { _ in [] }
    var search: @Sendable (_ query: String) async -> [WikiSearchHit] = { _ in [] }
}

extension WikiClient: DependencyKey {
    static let liveValue = WikiClient(
        load: { try await WikiIndexStore.shared.load(base: $0) },
        ensureLoaded: { try await WikiIndexStore.shared.ensureLoaded(base: $0) },
        note: { await WikiIndexStore.shared.note(slug: $0) },
        resolveLink: { await WikiIndexStore.shared.resolve(link: $0) },
        backlinks: { await WikiIndexStore.shared.backlinks(slug: $0) },
        notesForTag: { await WikiIndexStore.shared.notes(tag: $0) },
        search: { await WikiIndexStore.shared.search($0) }
    )
}

extension DependencyValues {
    var wikiClient: WikiClient {
        get { self[WikiClient.self] }
        set { self[WikiClient.self] = newValue }
    }
}
