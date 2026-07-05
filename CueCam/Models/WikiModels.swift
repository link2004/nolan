import Foundation

/// contentIndex.json の1エントリ(slugキーのオブジェクト)。contentはプレーンテキスト。
struct WikiNote: Equatable, Sendable, Identifiable {
    let slug: String
    let title: String
    let content: String
    let links: [String]
    let tags: [String]
    var id: String { slug }
}

struct WikiIndexEntry: Decodable, Sendable {
    let slug: String?
    let title: String?
    let content: String?
    let links: [String]?
    let tags: [String]?
}

/// 一覧・リンク表示用の軽量参照。TCA Stateにはこちらを置く(全文はWikiIndexStoreに残す)。
struct WikiNoteRef: Equatable, Sendable, Identifiable, Hashable {
    let slug: String
    let title: String
    var id: String { slug }
}

/// slugのパス階層から導出したフォルダツリー。
struct FolderNode: Equatable, Sendable, Identifiable, Hashable {
    let path: String
    let name: String
    var subfolders: [FolderNode]
    var notes: [WikiNoteRef]
    var id: String { path }
}

struct WikiSearchHit: Equatable, Sendable, Identifiable {
    let ref: WikiNoteRef
    let snippet: String
    var id: String { ref.slug }
}

struct TagCount: Equatable, Sendable, Identifiable {
    let tag: String
    let count: Int
    var id: String { tag }
}

struct WikiSummary: Equatable, Sendable {
    let root: FolderNode
    let noteCount: Int
    let tags: [TagCount]
}
