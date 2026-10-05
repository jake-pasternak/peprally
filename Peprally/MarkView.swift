import SwiftUI

/// The peprally mark drawn natively from the brand SVG's dot geometry —
/// vector-crisp at any size, animated at full display refresh rate.
///
/// Two motions:
///  · `.wave` — the desktop video's idle loop: dots fade in bottom-up, hold,
///    drain top-first. Pure opacity. Used wherever the mark sits idle.
///  · `.clock` — a one-shot build for the loading screen. The plus is four
///    arms at 12·3·6·9; the arms pop in one at a time in clock order
///    (top → right → bottom → left), each with a small landing overshoot.
///    No hand — the order alone carries the clockwise read.
struct MarkView: View {
    enum Motion { case wave, clock }

    var color: Color = .white
    var animated: Bool = true
    var style: Motion = .wave
    var startDelay: Double = 0

    // dot centers exactly matching the app icon (Figma node 429:2,
    // radius 19.5 on the 1024 canvas) — a plus whose horizontal arm sits
    // slightly below the vertical centre. The view fits the drawn bounds.
    private static let raw: [CGPoint] = [
        .init(x: 511.5, y: 334.5), .init(x: 511.5, y: 393.5),
        .init(x: 334.5, y: 511.5), .init(x: 393.5, y: 511.5),
        .init(x: 629.5, y: 511.5), .init(x: 688.5, y: 511.5),
        .init(x: 511.5, y: 629.5), .init(x: 511.5, y: 688.5),
    ]
    private static let dotR: CGFloat = 19.5
    private static let clusterMin: CGFloat = 334.5 - dotR
    private static let clusterSpan: CGFloat = (688.5 + dotR) - (334.5 - dotR)

    // row index by vertical position, bottom row = 0 (first to appear) — wave
    private static let rowByY: [CGFloat: Int] = [
        688.5: 0, 629.5: 1, 511.5: 2, 393.5: 3, 334.5: 4,
    ]

    // ── wave: measured from the desktop video frames ──────────────────────
    private static let period   = 2.7
    private static let inStart  = [0.00, 0.20, 0.33, 0.40, 0.47]
    private static let inDur    = [0.30, 0.17, 0.13, 0.15, 0.20]
    private static let outStart = [2.13, 2.05, 2.00, 1.93, 1.83]
    private static let outDur   = [0.20, 0.15, 0.13, 0.15, 0.17]

    // ── clock: arms pop in clock order 12·3·6·9, no hand ──────────────────
    // reveal order per raw dot: 0 top, 1 right, 2 bottom, 3 left
    private static let armOrder = [0, 0, 3, 3, 1, 1, 2, 2]
    private static let armStagger = 0.17   // gap between one arm and the next
    private static let armDur     = 0.34   // one arm's pop-in

    private let shownAt = Date()

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = Self.dotR / Self.clusterSpan * s

            TimelineView(.animation(minimumInterval: 1 / 60, paused: !animated)) { context in
                let t = context.date.timeIntervalSince(shownAt) - startDelay
                ZStack(alignment: .topLeading) {
                    ForEach(0..<Self.raw.count, id: \.self) { i in
                        let p = Self.raw[i]
                        let x = (p.x - Self.clusterMin) / Self.clusterSpan * s
                        let y = (p.y - Self.clusterMin) / Self.clusterSpan * s
                        let d = dot(i, at: t)

                        Circle()
                            .fill(color)
                            .frame(width: r * 2, height: r * 2)
                            .scaleEffect(d.scale)
                            .opacity(d.opacity)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dot(_ i: Int, at t: TimeInterval) -> (opacity: Double, scale: CGFloat) {
        guard animated else { return (1, 1) }
        switch style {
        case .wave:
            return (appearance(row: Self.rowByY[Self.raw[i].y] ?? 2, at: t), 1)
        case .clock:
            let local = (t - Double(Self.armOrder[i]) * Self.armStagger) / Self.armDur
            let lit = smoothstep(local)
            let scale = 0.5 + 0.5 * backOut(local)   // small pop as it lands
            return (lit, CGFloat(scale))
        }
    }

    /// 0...1 opacity of a row through the loop — wave.
    private func appearance(row: Int, at t: TimeInterval) -> Double {
        guard t > 0 else { return 0 }
        let u = t.truncatingRemainder(dividingBy: Self.period)
        let fadeIn  = smoothstep((u - Self.inStart[row])  / Self.inDur[row])
        let fadeOut = smoothstep((u - Self.outStart[row]) / Self.outDur[row])
        return fadeIn * (1 - fadeOut)
    }

    private func smoothstep(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }

    /// ease-out with a gentle overshoot — the "pop" as each arm lands.
    private func backOut(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        let c1 = 1.70158, c3 = 1.70158 + 1
        let p = c - 1
        return 1 + c3 * p * p * p + c1 * p * p
    }
}

#Preview {
    VStack(spacing: 40) {
        MarkView(color: .black, style: .clock)
            .frame(width: 96, height: 96)
        MarkView(color: .black, style: .wave)
            .frame(width: 96, height: 96)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.white)
}
