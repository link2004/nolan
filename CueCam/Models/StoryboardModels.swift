import Foundation

struct SBProject: Decodable, Equatable, Sendable, Identifiable {
    let note: String
    let title: String
    let client: String?
    let status: String?
    let state: String?
    let coverage: Double?
    let hasStoryboard: Bool?
    let thumbnail: String?
    let tags: [String]?
    let deliverables: [String]?

    var id: String { note }

    enum CodingKeys: String, CodingKey {
        case note, title, client, status, state, coverage, thumbnail, tags, deliverables
        case hasStoryboard = "has_storyboard"
    }
}

struct SBProjectsResponse: Decodable, Sendable {
    let projects: [SBProject]
}

/// /api/storyboard のボード状態。巨大な `base`(write-back用)はCodingKeysに含めず永久に無視する。
struct SBBoard: Decodable, Equatable, Sendable {
    let note: String
    let title: String
    let coverage: SBCoverage
    let beats: [SBBeat]

    enum CodingKeys: String, CodingKey { case note, title, coverage, beats }
}

struct SBCoverage: Decodable, Equatable, Sendable {
    let lines: Int
    let filled: Int
    let empty: Int
}

struct SBBeat: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let timecode: String?
    let heading: String?
    let vo: String?
    let voEn: String?
    let voJp: String?
    let lines: [SBLine]

    enum CodingKeys: String, CodingKey {
        case id, timecode, heading, vo, lines
        case voEn = "vo_en"
        case voJp = "vo_jp"
    }
}

struct SBLine: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let timecode: String?
    let script: String?
    let scriptJp: String?
    let shotDirection: String?
    let technique: [String]?
    let status: String?
    let reference: SBReference?

    enum CodingKeys: String, CodingKey {
        case id, timecode, script, technique, status, reference
        case scriptJp = "script_jp"
        case shotDirection = "shot_direction"
    }
}

struct SBReference: Decodable, Equatable, Sendable, Identifiable {
    let kind: String
    let path: String
    let poster: String?
    let caption: String?
    let sourceUrl: String?
    let platform: String?
    let timecode: String?

    var id: String { path }
    var isClip: Bool { kind == "clip" }

    enum CodingKeys: String, CodingKey {
        case kind, path, poster, caption, platform, timecode
        case sourceUrl = "source_url"
    }
}
