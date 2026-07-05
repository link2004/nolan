import ComposableArchitecture
import Foundation

@DependencyClient
struct StoryboardClient {
    var projects: @Sendable (_ base: URL) async throws -> [SBProject]
    var board: @Sendable (_ base: URL, _ note: String) async throws -> SBBoard
}

extension StoryboardClient: DependencyKey {
    static let liveValue = StoryboardClient(
        projects: { base in
            let url = base.appending(path: "api/projects")
            let response: SBProjectsResponse = try await HTTP.getJSON(url)
            return response.projects
        },
        board: { base, note in
            var components = URLComponents(url: base.appending(path: "api/storyboard"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "note", value: note)]
            guard let url = components?.url else { throw HTTPError.invalidURL(note) }
            return try await HTTP.getJSON(url)
        }
    )
}

extension DependencyValues {
    var storyboardClient: StoryboardClient {
        get { self[StoryboardClient.self] }
        set { self[StoryboardClient.self] = newValue }
    }
}
