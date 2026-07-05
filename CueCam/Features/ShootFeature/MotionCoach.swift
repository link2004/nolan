import SwiftUI

/// スクリプトから検出するカメラモーションの種類
enum CameraMotion: Equatable {
    case panLeft, panRight, whipPan
    case tiltUp, tiltDown
    case topDown
    case dollyIn, dollyOut
    case track
    case orbit
    case handheld

    var label: String {
        switch self {
        case .panLeft: "← PAN"
        case .panRight: "PAN →"
        case .whipPan: "WHIP PAN"
        case .tiltUp: "TILT UP"
        case .tiltDown: "TILT DOWN"
        case .topDown: "TOP-DOWN"
        case .dollyIn: "DOLLY IN"
        case .dollyOut: "DOLLY OUT"
        case .track: "TRACK / SLIDER"
        case .orbit: "ORBIT"
        case .handheld: "HANDHELD"
        }
    }
}

/// shot_direction / script / technique の自由文からカメラモーションを検出する。
// TODO: DirectorClient(Claude API)導入時はAI側でモーションを構造化して返す形に置き換え候補
enum MotionCoach {
    /// フレーミングガイドの緑(SBTheme.mark系を撮影画面向けに一段明るくしたもの)
    static let green = Color.rgb(0x8fbf9a)

    static func detect(_ script: ShotScript) -> CameraMotion? {
        let haystack = ([script.text, script.direction ?? ""] + script.techniques)
            .joined(separator: " ")
            .lowercased()

        func matches(_ pattern: String) -> Bool {
            haystack.range(of: pattern, options: .regularExpression) != nil
        }

        // 特異性の高い語から順に判定(先勝ち)
        if matches("whip[- ]?pan") { return .whipPan }
        if matches("overhead|top[- ]?down|bird'?s[- ]?eye|from above|looking down") { return .topDown }
        if matches("tilt(s|ing)? down|from (up|top) to (down|bottom)|up to down") { return .tiltDown }
        if matches("tilt(s|ing)? up|down to up") { return .tiltUp }
        if matches("\\bpan(s|ned|ning)?\\b") {
            return matches("right to left") ? .panLeft : .panRight
        }
        if matches("dolly (out|back)|pull(s|ing)? (back|out|away)|zoom(s|ing)? out") { return .dollyOut }
        if matches("\\bdolly\\b|push(es|ing)?[- ]?in|zoom(s|ing)? in|move(s|ing)? in") { return .dollyIn }
        if matches("\\borbit(s|ing)?\\b|arc(s|ing)? around|circle(s|ing)? around") { return .orbit }
        if matches("\\bslider\\b|\\btrack(s|ing)?\\b|\\bfollows?\\b|\\bglide(s|ing)?\\b|\\bacross\\b") { return .track }
        if matches("handheld|hand-held") { return .handheld }
        return nil
    }
}

/// カメラ映像の中央に置くフレーミングガイド(緑のコーナーブラケット)。
/// モーション指示はこのガイド枠の位置を基準に、該当する辺の外側へ小さく描かれる
struct FramingGuideOverlay: View {
    let motion: CameraMotion?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let guide = CGRect(
                x: (size.width - size.width * 0.30) / 2,
                y: (size.height - size.height * 0.56) / 2,
                width: size.width * 0.30,
                height: size.height * 0.56
            )

            CornerBrackets(rect: guide)
                .stroke(
                    MotionCoach.green.opacity(0.9),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .shadow(color: .black.opacity(0.5), radius: 2)

            if let motion {
                MotionHint(motion: motion)
                    .position(Self.hintPosition(for: motion, guide: guide))
            }
        }
        .allowsHitTesting(false)
    }

    /// モーションの向きに応じてガイド枠のどの辺に指示を置くか
    private static func hintPosition(for motion: CameraMotion, guide: CGRect) -> CGPoint {
        switch motion {
        case .panRight, .whipPan, .track, .dollyOut:
            CGPoint(x: guide.maxX + 64, y: guide.midY)
        case .panLeft:
            CGPoint(x: guide.minX - 64, y: guide.midY)
        case .tiltUp, .topDown:
            CGPoint(x: guide.midX, y: guide.minY - 34)
        case .tiltDown, .dollyIn, .orbit, .handheld:
            CGPoint(x: guide.midX, y: guide.maxY + 34)
        }
    }
}

/// ガイド枠の四隅だけを描くブラケット(AF枠風)
struct CornerBrackets: Shape {
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        var p = Path()
        let arm = min(rect.width, rect.height) * 0.22

        // 左上
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        // 右上
        p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        // 右下
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        // 左下
        p.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return p
    }
}

/// ガイド枠の外側に置く小さなモーション指示(描かれるアニメーションの矢印 + ラベル)
struct MotionHint: View {
    let motion: CameraMotion

    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            MotionGlyph(motion: motion, progress: progress)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(MotionCoach.green.opacity(0.95))
                .frame(width: 48, height: 26)
            Text(motion.label)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(SBTheme.fg1.opacity(0.9))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            progress = 0
            withAnimation(
                .easeInOut(duration: motion == .whipPan ? 0.45 : 1.4)
                .repeatForever(autoreverses: false)
            ) {
                progress = 1
            }
        }
    }
}

/// モーション毎の注釈パス。arrowhead含めて1本のパスにして trim で「描かれていく」動きを作る
struct MotionGlyph: Shape {
    let motion: CameraMotion
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        fullPath(in: rect).trimmedPath(from: 0, to: progress)
    }

    private func fullPath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let headSize = min(w, h) * 0.28
        var p = Path()

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        /// 進行方向 direction(ラジアン)の矢じり(後方±150°の2本線)
        func addHead(at point: CGPoint, direction: CGFloat) {
            for offset in [CGFloat.pi * 5 / 6, -CGFloat.pi * 5 / 6] {
                let a = direction + offset
                p.move(to: point)
                p.addLine(to: CGPoint(
                    x: point.x + cos(a) * headSize,
                    y: point.y + sin(a) * headSize
                ))
            }
        }

        func addQuadArrow(from start: CGPoint, to end: CGPoint, control: CGPoint) {
            p.move(to: start)
            p.addQuadCurve(to: end, control: control)
            addHead(at: end, direction: atan2(end.y - control.y, end.x - control.x))
        }

        func addLineArrow(from start: CGPoint, to end: CGPoint) {
            p.move(to: start)
            p.addLine(to: end)
            addHead(at: end, direction: atan2(end.y - start.y, end.x - start.x))
        }

        switch motion {
        case .panRight:
            addQuadArrow(from: pt(0.05, 0.65), to: pt(0.95, 0.65), control: pt(0.5, 0.1))

        case .panLeft:
            addQuadArrow(from: pt(0.95, 0.65), to: pt(0.05, 0.65), control: pt(0.5, 0.1))

        case .whipPan:
            addLineArrow(from: pt(0.05, 0.5), to: pt(0.95, 0.5))
            // スピードライン
            p.move(to: pt(0.12, 0.22)); p.addLine(to: pt(0.42, 0.22))
            p.move(to: pt(0.12, 0.78)); p.addLine(to: pt(0.42, 0.78))

        case .tiltDown:
            addQuadArrow(from: pt(0.4, 0.05), to: pt(0.4, 0.95), control: pt(0.95, 0.5))

        case .tiltUp:
            addQuadArrow(from: pt(0.4, 0.95), to: pt(0.4, 0.05), control: pt(0.95, 0.5))

        case .topDown:
            // 地面ライン → 上から振り下ろすアーク
            p.move(to: pt(0.15, 0.92)); p.addLine(to: pt(0.85, 0.92))
            addQuadArrow(from: pt(0.08, 0.2), to: pt(0.58, 0.72), control: pt(0.85, 0.05))

        case .dollyIn:
            // 被写体フレーム + それへ向かう矢印
            p.addRoundedRect(
                in: CGRect(x: rect.minX + 0.62 * w, y: rect.minY + 0.26 * h, width: 0.33 * w, height: 0.48 * h),
                cornerSize: CGSize(width: 3, height: 3)
            )
            addLineArrow(from: pt(0.05, 0.5), to: pt(0.52, 0.5))

        case .dollyOut:
            p.addRoundedRect(
                in: CGRect(x: rect.minX + 0.05 * w, y: rect.minY + 0.26 * h, width: 0.33 * w, height: 0.48 * h),
                cornerSize: CGSize(width: 3, height: 3)
            )
            addLineArrow(from: pt(0.48, 0.5), to: pt(0.95, 0.5))

        case .track:
            // レール2本 + 平行移動の矢印
            p.move(to: pt(0.08, 0.8)); p.addLine(to: pt(0.92, 0.8))
            p.move(to: pt(0.08, 0.93)); p.addLine(to: pt(0.92, 0.93))
            addLineArrow(from: pt(0.08, 0.4), to: pt(0.92, 0.4))

        case .orbit:
            let center = pt(0.5, 0.5)
            let radius = min(w, h) * 0.42
            let endAngle = Angle.degrees(30)
            p.move(to: CGPoint(
                x: center.x + cos(CGFloat(Angle.degrees(120).radians)) * radius,
                y: center.y + sin(CGFloat(Angle.degrees(120).radians)) * radius
            ))
            p.addArc(center: center, radius: radius, startAngle: .degrees(120), endAngle: .degrees(390), clockwise: false)
            let θ = CGFloat(endAngle.radians)
            let end = CGPoint(x: center.x + cos(θ) * radius, y: center.y + sin(θ) * radius)
            addHead(at: end, direction: atan2(cos(θ), -sin(θ)))

        case .handheld:
            // 手持ちの揺れを波線で
            p.move(to: pt(0.05, 0.5))
            p.addQuadCurve(to: pt(0.3, 0.5), control: pt(0.175, 0.15))
            p.addQuadCurve(to: pt(0.55, 0.5), control: pt(0.425, 0.85))
            p.addQuadCurve(to: pt(0.8, 0.5), control: pt(0.675, 0.15))
            addHead(at: pt(0.8, 0.5), direction: atan2(0.5 - 0.15, 0.8 - 0.675))
        }

        return p
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        SBTheme.bg.ignoresSafeArea()
        FramingGuideOverlay(motion: .panRight)
            .aspectRatio(16 / 9, contentMode: .fit)
    }
}
