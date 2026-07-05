import ComposableArchitecture
import Foundation

@DependencyClient
struct VaultspaceClient {
    var manifest: @Sendable (_ base: URL) async throws -> VaultManifest
}

extension VaultspaceClient: DependencyKey {
    static let liveValue = VaultspaceClient(
        manifest: { base in
            try await HTTP.getJSON(base.appending(path: "api/vault"))
        }
    )
}

extension DependencyValues {
    var vaultspaceClient: VaultspaceClient {
        get { self[VaultspaceClient.self] }
        set { self[VaultspaceClient.self] = newValue }
    }
}
