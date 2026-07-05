import SwiftUI

// Webの3サーフェスから抽出したデザイントークン。タブごとに世界観が異なる:
// Storyboard = ダークシネマ(ink + 温白 + 抹茶) / Vaultspace = 紙(paper + ink + yen-green)
// Wiki = Quartzテーマ(cream/ink、ライト・ダーク両対応)

extension Color {
    /// 0xRRGGBB リテラルからColorを作る(テーマ定義用)。
    static func rgb(_ hex: UInt32, opacity: Double = 1) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    /// Instrument Serif(バンドル済み)。見出し・VO・スクリプト行の署名フェイス。
    static func instrumentSerif(_ size: CGFloat) -> Font {
        .custom("Instrument Serif", size: size)
    }
    static func instrumentSerifItalic(_ size: CGFloat) -> Font {
        .custom("Instrument Serif", size: size).italic()
    }
}

/// Storyboard Studio (app.css) — ダークシネマ。
enum SBTheme {
    static let bg = Color.rgb(0x0a0a0b)            // ink-900
    static let bgRaised = Color.rgb(0x121214)      // ink-800
    static let surface = Color.rgb(0x1b1b1e)       // ink-700 (card)
    static let track = Color.rgb(0x26262a)         // ink-600 (coverage track)
    static let fg1 = Color.rgb(0xf4f1ea)           // 温白
    static let fg2 = Color.rgb(0xc4c2bb)           // silver-100
    static let fg3 = Color.rgb(0x6d6c67)           // ash-400 (ash-600だと暗すぎるためモバイルは一段明るく)
    static let hairline = Color.rgb(0xf4f1ea, opacity: 0.12)
    static let hairlineStrong = Color.rgb(0xf4f1ea, opacity: 0.22)
    static let mark = Color.rgb(0x5a6f60)          // yen-green-soft (coverage fill)
    static let crimson = Color.rgb(0x8e2c2c)
    static let amberBg = Color.rgb(0x785c26, opacity: 0.16)
    static let amberText = Color.rgb(0xe6d3ad)
    static let greenBg = Color.rgb(0x45584c, opacity: 0.18)
    static let greenText = Color.rgb(0xcfe0d4)
}

/// Vaultspace (index.css / GalleryCanvas) — 温かい紙のライトテーマ。
enum VSTheme {
    static let paper = Color.rgb(0xf7f4ee)         // canvas背景
    static let paperHi = Color.rgb(0xfffdf8)       // カード面
    static let paperLow = Color.rgb(0xe7ded1)      // プレースホルダー
    static let ink = Color.rgb(0x11100e)
    static let charcoal = Color.rgb(0x2a2926)
    static let silverDark = Color.rgb(0x77716a)
    static let green = Color.rgb(0x4c6f45)         // yen-green (選択・アクセント)
    static let greenDark = Color.rgb(0x2f4e34)
    static let crimson = Color.rgb(0x9f332f)
    static let line = Color.rgb(0x11100e, opacity: 0.22)
    static let lineFaint = Color.rgb(0x11100e, opacity: 0.2)
    static let edge = Color.rgb(0x11100e, opacity: 0.045)   // マップのエッジ線
    static let edgeFocused = Color.rgb(0x4c6f45, opacity: 0.22)
    static let watermark = Color.rgb(0x11100e, opacity: 0.08)
}

/// Quartz wiki (quartz.config.ts theme) — ライト/ダーク両対応。
struct WikiPalette {
    let light: Color      // ページ背景
    let lightgray: Color  // 罫線・タグ枠
    let gray: Color       // 弱い文字・下線
    let darkgray: Color   // 第二文字色
    let dark: Color       // 本文・見出し
    let secondary: Color  // アクセント緑(リンク・アクティブ)
    let tertiary: Color
    let highlight: Color

    static let lightMode = WikiPalette(
        light: .rgb(0xf6f2e8),
        lightgray: .rgb(0xe6dfd0),
        gray: .rgb(0xa8a298),
        darkgray: .rgb(0x57534b),
        dark: .rgb(0x1b1a17),
        secondary: .rgb(0x3f5246),
        tertiary: .rgb(0x5a6f60),
        highlight: .rgb(0x5a6f60, opacity: 0.12)
    )

    static let darkMode = WikiPalette(
        light: .rgb(0x0e0e0f),
        lightgray: .rgb(0x262529),
        gray: .rgb(0x6d6c67),
        darkgray: .rgb(0xc4c2bb),
        dark: .rgb(0xf4f1ea),
        secondary: .rgb(0x8aa896),
        tertiary: .rgb(0x6b8475),
        highlight: .rgb(0x8aa896, opacity: 0.15)
    )

    static func current(_ scheme: ColorScheme) -> WikiPalette {
        scheme == .dark ? .darkMode : .lightMode
    }
}
