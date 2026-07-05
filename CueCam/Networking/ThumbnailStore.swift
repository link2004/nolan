import ImageIO
import SwiftUI
import UIKit

/// ポスター画像のダウンサンプル済みメモリキャッシュ。
///
/// R2の原寸JPGをAsyncImageでそのまま使うと、タイルには過大な解像度を
/// 90枚ぶんフルデコードすることになり、回転・遷移がカクつく。
/// ここで一度だけタイルサイズ(最大480px)に縮小デコードし、以後は
/// メモリから即描画する。バイト層はURLCacheが効くので再起動後も速い。
@MainActor
@Observable
final class ThumbnailStore {
    static let shared = ThumbnailStore()

    private(set) var images: [String: UIImage] = [:]
    private var inFlight: Set<String> = []

    func image(for url: URL) -> UIImage? {
        images[url.absoluteString]
    }

    /// マニフェスト取得直後に全ポスターをまとめて温める。
    func prefetch(_ urls: [URL]) {
        for url in urls { request(url) }
    }

    func request(_ url: URL) {
        let key = url.absoluteString
        guard images[key] == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)
        Task(priority: .utility) {
            let image = await Self.downsample(url: url, maxPixel: 480)
            inFlight.remove(key)
            if let image {
                images[key] = image
            }
        }
    }

    /// バイト取得(URLCache背後)→ CGImageSource でタイルサイズに縮小デコード。
    /// フル解像度のビットマップを一度も作らないのがポイント。
    private nonisolated static func downsample(url: URL, maxPixel: CGFloat) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
