import ComposableArchitecture
import SwiftUI

struct VideoDetailView: View {
    let store: StoreOf<VideoDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                actionRow

                if let summary = store.video.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(VSTheme.charcoal)
                        .lineSpacing(4)
                }

                if let techniques = store.video.techniques, !techniques.isEmpty {
                    techniqueChips(techniques)
                }

                if !store.clips.isEmpty {
                    clipRail
                }

                if !store.stills.isEmpty {
                    stillGrid
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VSTheme.paper)
        .presentationBackground(VSTheme.paper)
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // トップライン: 動画タイプのラベル(Webのkicker相当)
            if let type = store.video.videoTypeLabel {
                Text(type.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(VSTheme.charcoal)
            }

            Text(store.video.title)
                .font(.instrumentSerif(32))
                .foregroundStyle(VSTheme.ink)
                .lineSpacing(0)
        }
    }

    // MARK: - アクション行(WIKI / SOURCE)

    /// Webの黒ボタン行。ink面 + paperHi文字のダークボタン。
    private var actionRow: some View {
        HStack(spacing: 8) {
            if let wikiUrl = store.video.wikiUrl, let url = URL(string: wikiUrl) {
                Link(destination: url) {
                    darkButtonLabel("WIKI")
                }
            }
            if let sourceUrl = store.video.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    darkButtonLabel("SOURCE")
                }
            }
        }
    }

    private func darkButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy))
            .tracking(1)
            .foregroundStyle(VSTheme.paperHi)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(VSTheme.ink, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - テクニックチップ

    private func techniqueChips(_ techniques: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(techniques.prefix(8), id: \.self) { technique in
                    Text(technique)
                        .font(.system(size: 11))
                        .foregroundStyle(VSTheme.charcoal)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .overlay {
                            Capsule().stroke(VSTheme.line, lineWidth: 1)
                        }
                }
            }
            .padding(.vertical, 1) // strokeの見切れ防止
        }
    }

    // MARK: - セクション見出し

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(VSTheme.silverDark)
    }

    // MARK: - クリップレール

    private var clipRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CLIPS")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(store.clips) { clip in
                        clipCell(clip)
                    }
                }
            }
        }
    }

    private func clipCell(_ clip: VaultClip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let mediaUrl = clip.mediaUrl,
                   let url = MediaURL.url(mediaPath: mediaUrl) {
                    InlineClipPlayer(
                        url: url,
                        posterURL: clip.posterUrl.flatMap { MediaURL.url(mediaPath: $0) }
                    )
                } else {
                    mediaPlaceholder("CLIP OFFLINE")
                }
            }
            .frame(width: 220, height: 124) // 16:9を維持
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // 強い行(テクニック or タイトル) + キャプション(timecode · platform)
            if let strong = clip.technique ?? clip.title, !strong.isEmpty {
                Text(strong)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VSTheme.ink)
                    .lineLimit(2)
            }
            if let caption = clipCaption(clip) {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(VSTheme.silverDark)
                    .lineLimit(1)
            }
        }
        .frame(width: 220, alignment: .leading)
        .padding(7)
        .background(VSTheme.paperHi)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(VSTheme.line, lineWidth: 1)
        }
    }

    /// "timecode · platform" 形式のキャプション。どちらもなければnil。
    private func clipCaption(_ clip: VaultClip) -> String? {
        let parts = [clip.timecode, clip.platform].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - スチルグリッド

    private var stillGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("STILLS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(store.stills) { still in
                    stillCell(still)
                }
            }
        }
    }

    private func stillCell(_ still: VaultStill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let mediaUrl = still.mediaUrl,
                   let url = MediaURL.url(mediaPath: mediaUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        VSTheme.paperLow
                    }
                } else {
                    mediaPlaceholder("STILL OFFLINE")
                }
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .background(VSTheme.paperLow)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            if let facets = still.facets {
                facetLabels(facets)
            }

            if let palette = still.palette, !palette.isEmpty {
                paletteSwatches(palette)
            }
        }
        .padding(7)
        .background(VSTheme.paperHi)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(VSTheme.line, lineWidth: 1)
        }
    }

    /// オフライン時のプレースホルダー面(paperLow + 中央ラベル)。
    private func mediaPlaceholder(_ label: String) -> some View {
        VSTheme.paperLow
            .overlay {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(VSTheme.ink.opacity(0.52))
            }
    }

    private func facetLabels(_ facets: VaultFacets) -> some View {
        let labels = [facets.shotSize, facets.angle, facets.subject].compactMap(\.self)
        return Text(labels.joined(separator: " · ").uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(VSTheme.silverDark)
            .lineLimit(1)
    }

    private func paletteSwatches(_ palette: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(palette, id: \.self) { hex in
                if let color = Color(hex: hex) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(VSTheme.line, lineWidth: 1)
                        }
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
