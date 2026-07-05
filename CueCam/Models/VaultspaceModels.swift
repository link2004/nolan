import Foundation

struct VaultManifest: Decodable, Equatable, Sendable {
    let schema: Int?
    let counts: VaultCounts?
    let videos: [VaultVideo]
    let clips: [VaultClip]
    let stills: [VaultStill]
    let space: VaultSpace
}

struct VaultCounts: Decodable, Equatable, Sendable {
    let videos: Int?
    let clips: Int?
    let stills: Int?
}

struct VaultVideo: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let videoTypeLabel: String?
    let platform: String?
    let sourceUrl: String?
    let wikiUrl: String?
    let posterUrl: String?
    let techniques: [String]?
    let summary: String?
    let clipIds: [String]?
    let stillIds: [String]?
    let map: VaultPoint?
    let order: Int?
}

struct VaultPoint: Decodable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct VaultClip: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let videoId: String?
    let title: String?
    let technique: String?
    let mediaUrl: String?
    let posterUrl: String?
    let sourceUrl: String?
    let platform: String?
    let timecode: String?
    let caption: String?
}

struct VaultStill: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let videoId: String?
    let title: String?
    let mediaUrl: String?
    let sourceUrl: String?
    let platform: String?
    let timecode: String?
    let description: String?
    let facets: VaultFacets?
    let palette: [String]?
}

struct VaultFacets: Decodable, Equatable, Sendable {
    let shotSize: String?
    let angle: String?
    let subject: String?
    let lighting: String?
    let location: String?
}

struct VaultSpace: Decodable, Equatable, Sendable {
    let order: [String]?
    let positions: [String: VaultPoint]?
}
