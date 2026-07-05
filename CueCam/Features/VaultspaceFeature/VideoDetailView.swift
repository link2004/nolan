import ComposableArchitecture
import SwiftUI

struct VideoDetailView: View {
    let store: StoreOf<VideoDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let techniques = store.video.techniques, !techniques.isEmpty {
                    techniqueChips(techniques)
                }

                if let summary = store.video.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.body)
                }

                if !store.clips.isEmpty {
                    clipRail
                }

                if !store.stills.isEmpty {
                    stillGrid
                }

                if let wikiUrl = store.video.wikiUrl, let url = URL(string: wikiUrl) {
                    Link("Open in Wiki", destination: url)
                        .font(.callout)
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.video.title)
                .font(.title2.bold())

            HStack(spacing: 8) {
                if let type = store.video.videoTypeLabel {
                    badge(type, tint: .accentColor)
                }
                if let platform = store.video.platform {
                    badge(platform, tint: .secondary)
                }
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
    }

    private func techniqueChips(_ techniques: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(techniques, id: \.self) { technique in
                    Text(technique)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    // MARK: - クリップレール

    private var clipRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clips")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(store.clips) { clip in
                        clipCell(clip)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clipCell(_ clip: VaultClip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let mediaUrl = clip.mediaUrl,
               let url = MediaURL.url(mediaPath: mediaUrl) {
                InlineClipPlayer(
                    url: url,
                    posterURL: clip.posterUrl.flatMap { MediaURL.url(mediaPath: $0) }
                )
                .frame(width: 220, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemFill))
                    .frame(width: 220, height: 124)
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            if let caption = clip.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 220, alignment: .leading)
            }
        }
    }

    // MARK: - スチルグリッド

    private var stillGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stills")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(store.stills) { still in
                    stillCell(still)
                }
            }
        }
    }

    private func stillCell(_ still: VaultStill) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let mediaUrl = still.mediaUrl,
                   let url = MediaURL.url(mediaPath: mediaUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemFill)
                    }
                } else {
                    Color(.systemFill)
                }
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let facets = still.facets {
                facetLabels(facets)
            }

            if let palette = still.palette, !palette.isEmpty {
                paletteSwatches(palette)
            }
        }
    }

    private func facetLabels(_ facets: VaultFacets) -> some View {
        let labels = [facets.shotSize, facets.angle, facets.subject].compactMap(\.self)
        return Text(labels.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func paletteSwatches(_ palette: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(palette, id: \.self) { hex in
                if let color = Color(hex: hex) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 18, height: 18)
                }
            }
        }
    }
}

extension Color {
    /// "#RRGGBB" / "RRGGBB" 形式のhex文字列からColorを作る(不正な文字列はnil)。
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespaces)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
