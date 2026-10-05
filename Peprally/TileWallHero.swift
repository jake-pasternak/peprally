import SwiftUI

/// The signup hero: a wall of pastel tiles, every tile carrying one of the
/// community's topics. Tiles pop in as a staggered wave, each row drifts
/// slowly in alternating directions, and the wall stays alive by color:
/// each card breathes gently between two pastels on its own slow cycle.
/// The emojis themselves never move.
///
/// Rendered as a single Canvas — one draw pass instead of ~130 diffed
/// views — on a 30fps clock (the drift is 9pt/s; nothing here needs 120).
/// The atmosphere blur QuestionHero wants is baked into the same pass via
/// `blurRadius`, so no full-size Gaussian re-runs outside the canvas.
struct TileWallHero: View {
    /// blur applied inside the draw pass (QuestionHero's atmosphere)
    var blurRadius: CGFloat = 0
    /// tile opacity baked into the draw pass — a wrapping .opacity() would
    /// create a transparency layer whose bottom edge can seam against the
    /// page white; drawing at reduced alpha composites edge-free
    var tileOpacity: Double = 1

    private struct Row {
        let y: CGFloat
        let direction: CGFloat
        let phase: CGFloat
        var blur: CGFloat = 0
        let tiles: [(hex: UInt, emoji: String)]
    }

    private static let rows: [Row] = [
        // feeder row above the visible edge — mostly offscreen, it exists
        // so the blur has neighbors to sample and the top row doesn't
        // fade toward white
        Row(y: -89, direction: -1, phase: -44, tiles: [
            (0xEBEBEB, "🧪"), (0xE9E9E9, "🍊"), (0xD8D8D8, "🫧"),
            (0xEAEAEA, "🧴"), (0xDFDFDF, "❄️"), (0xE8E8E8, "🌾"),
        ]),
        Row(y: -15, direction: 1, phase: -19, tiles: [
            (0xE9E9E9, "🫀"), (0xEAEAEA, "😴"), (0xEBEBEB, "🔬"),
            (0xE8E8E8, "🍎"), (0xDFDFDF, "🧫"), (0xD8D8D8, "🩺"),
        ]),
        Row(y: 59, direction: -1, phase: -62, tiles: [
            (0xE9E9E9, "🧬"), (0xD3D3D3, "🧠"), (0xE9E9E9, "🏋️"),
            (0xEAEAEA, "💊"), (0xEBEBEB, "🥗"), (0xD3D3D3, "🏃"),
            (0xDFDFDF, "🧪"),
        ]),
        Row(y: 133, direction: 1, phase: -13, tiles: [
            (0xE9E9E9, "🥦"), (0xEAEAEA, "☀️"), (0xEBEBEB, "💉"),
            (0xE8E8E8, "🚴"), (0xE8E8E8, "💤"), (0xD8D8D8, "🌱"),
        ]),
        Row(y: 207, direction: -1, phase: -56, tiles: [
            (0xE9E9E9, "😌"), (0xD3D3D3, "⚡"), (0xE9E9E9, "🫁"),
            (0xEAEAEA, "🧘"), (0xEBEBEB, "📊"), (0xE8E8E8, "❤️"),
            (0xDFDFDF, "🥇"),
        ]),
        Row(y: 281, direction: 1, phase: -34, blur: 5, tiles: [
            (0xE9E9E9, "💧"), (0xEAEAEA, "🫐"), (0xEBEBEB, "⏱️"),
            (0xE8E8E8, "🏊"), (0xD3D3D3, "🌿"), (0xDFDFDF, "🍳"),
        ]),
    ]

    /// each pastel transitions to its opposite temperature — warm tiles
    /// cool down, cool tiles warm up — so the change is actually visible
    private static let altOf: [UInt: UInt] = [
        0xE9E9E9: 0xDFDFDF,   // blush → blue-gray
        0xEAEAEA: 0xD8D8D8,   // cream → slate
        0xEBEBEB: 0xE9E9E9,   // sage → blush
        0xE8E8E8: 0xDFDFDF,   // neutral → blue-gray
        0xDFDFDF: 0xE9E9E9,   // blue-gray → blush
        0xD8D8D8: 0xEAEAEA,   // slate → cream
        0xD3D3D3: 0xE9E9E9,   // gray → blush
    ]

    private let pitch: CGFloat = 75
    private let driftSpeed: Double = 9   // points per second

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let shownAt = Date()

    /// how far the canvas extends above its layout frame, so the blur
    /// filter's edge fade sits offscreen instead of washing the first
    /// rows toward white
    private let topBleed: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            // when the wall is atmosphere (blurred), render at quarter
            // resolution and upscale — a blur has no detail to lose, and
            // the per-frame GPU cost drops ~16×
            let down: CGFloat = blurRadius > 0 ? 4 : 1

            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                let elapsed = reduceMotion ? 999 : context.date.timeIntervalSince(shownAt)

                Canvas { ctx, size in
                    // fixed 64pt tiles on every device — the wrap covers any
                    // width, and the geometry matches the Figma frames 1:1
                    var base = ctx
                    base.scaleBy(x: 1 / down, y: 1 / down)
                    base.translateBy(x: 0, y: topBleed)
                    base.opacity = tileOpacity
                    // filter radii live in the scaled drawing space, so they
                    // need no adjustment for the downsampled canvas
                    if blurRadius > 0 {
                        base.addFilter(.blur(radius: blurRadius))
                    }
                    for (rowIndex, row) in Self.rows.enumerated() {
                        var rctx = base
                        if row.blur > 0 { rctx.addFilter(.blur(radius: row.blur)) }
                        drawRow(row, index: rowIndex, time: t, elapsed: elapsed, in: rctx)
                    }
                }
                .frame(width: geo.size.width / down,
                       height: (geo.size.height + topBleed) / down)
                .scaleEffect(down, anchor: .topLeading)
                .offset(y: -topBleed)
            }
        }
    }

    private func drawRow(_ row: Row, index rowIndex: Int,
                         time: Double, elapsed: Double, in ctx: GraphicsContext) {
        let rowWidth = CGFloat(row.tiles.count) * pitch
        let travel = CGFloat(time * driftSpeed) * row.direction + row.phase
        let offset = ((travel.truncatingRemainder(dividingBy: rowWidth)) + rowWidth)
            .truncatingRemainder(dividingBy: rowWidth)

        // two copies of the row give seamless wrap-around
        for i in 0..<(row.tiles.count * 2) {
            let tile = row.tiles[i % row.tiles.count]
            // entrance: a diagonal wave of pops across the wall
            let delay = 0.10 * Double(rowIndex) + 0.05 * Double(i % row.tiles.count)
            let p = min(1, max(0, (elapsed - delay) / 0.5))
            let ease = 1 - pow(1 - p, 3)
            guard ease > 0 else { continue }

            // each card transitions between its own pastel and its
            // opposite temperature on its own cycle — a pure function of time
            let gi = rowIndex * 10 + i % row.tiles.count
            let period = 6 + 4 * frac(Double(gi) * 0.7548)
            let phase = period * frac(Double(gi) * 0.618)
            let k = 0.5 - 0.5 * cos(2 * .pi * (time + phase) / period)
            let alt = Self.altOf[tile.hex] ?? tile.hex
            let fill = blend(tile.hex, alt, k)

            let x = CGFloat(i) * pitch + offset - rowWidth
            let center = CGPoint(x: x + 32, y: row.y + 32)
            let side = 64 * (0.6 + 0.4 * ease)
            let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2,
                              width: side, height: side)

            var tctx = ctx
            tctx.opacity = ease
            tctx.fill(
                Path(roundedRect: rect, cornerRadius: 10 * (side / 64), style: .continuous),
                with: .color(fill)
            )
            tctx.draw(
                Text(tile.emoji).font(.system(size: 26 * (side / 64))),
                at: center
            )
        }
    }

    private func blend(_ a: UInt, _ b: UInt, _ k: Double) -> Color {
        func ch(_ hex: UInt, _ shift: UInt) -> Double { Double((hex >> shift) & 0xFF) / 255 }
        return Color(
            red: ch(a, 16) + (ch(b, 16) - ch(a, 16)) * k,
            green: ch(a, 8) + (ch(b, 8) - ch(a, 8)) * k,
            blue: ch(a, 0) + (ch(b, 0) - ch(a, 0)) * k
        )
    }

    private func frac(_ x: Double) -> Double { x - x.rounded(.down) }
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    TileWallHero()
        .frame(height: 306)
}
