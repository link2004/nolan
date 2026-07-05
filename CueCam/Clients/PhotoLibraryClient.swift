import ComposableArchitecture
import Photos

@DependencyClient
struct PhotoLibraryClient {
    /// 動画ファイルをフォトライブラリに保存する(初回はadd-onlyの許可プロンプトが出る)
    var saveVideo: @Sendable (URL) async throws -> Void
}

extension PhotoLibraryClient: DependencyKey {
    static let liveValue = PhotoLibraryClient(
        saveVideo: { url in
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    )

    static let testValue = PhotoLibraryClient()

    static let previewValue = PhotoLibraryClient(saveVideo: { _ in })
}

extension DependencyValues {
    var photoLibrary: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }
}
