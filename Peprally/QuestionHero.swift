import SwiftUI

/// The signup hero, v2: the product's atom — a question with a verified
/// answer — floating as the front of a small card deck over the tile
/// wall, which recedes into a heavily blurred backdrop that dissolves
/// smoothly into the page below. Motion is slow and slight.
struct QuestionHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // the wall becomes atmosphere, melting into the page — the
            // blur happens inside the wall's own draw pass (see TileWallHero)
            // blur 20 ≈ Figma's layer blur 10 (different Gaussian conventions).
            // Opacity is baked into the draw pass and ONE dissolve gradient
            // sits on top, opaque white for the hero's last 15% — no
            // transparency layer, no seam against the page.
            TileWallHero(blurRadius: 20, tileOpacity: 0.5)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0),    location: 0.30),
                            .init(color: .white.opacity(0.88), location: 0.72),
                            .init(color: .white,               location: 0.85),
                            .init(color: .white,               location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // 30fps: the float is a 3pt sine at 0.35 rad/s — display-rate
            // redraws of the card stack buy nothing visible
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate

                ZStack {
                    bubble("🧬", 40, 0xDFDFDF, x: -156, y: -92, t: t, phase: 0.0)
                    bubble("💪", 40, 0xE9E9E9, x: 156, y: -92, t: t, phase: 2.1)
                    bubble("🧠", 40, 0xEAEAEA, x: -156, y: 96, t: t, phase: 4.2)
                    bubble("⚡", 40, 0xE8E8E8, x: 156, y: 96, t: t, phase: 1.3)

                    deck(t: t)
                }
                .offset(y: 65)
            }
        }
        // no clip: the tile wall clips itself, and clipping the deck here
        // sliced the question card's soft shadow at the hero's bottom edge —
        // that hard slice was the visible "cut line" under the hero
    }

    /// the front card plus two resting behind it, edges peeking above
    private func deck(t: Double) -> some View {
        let float = reduceMotion ? 0.0 : 3 * sin(t * 0.35)
        let sway = reduceMotion ? 0.0 : 0.4 * sin(t * 0.3 + 1)

        // shadow BEFORE the animated offset: the shadowed card is cached
        // once and moved as a unit, instead of re-rasterizing 30×/s
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.55))
                .frame(width: 252, height: 180)
                .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
                .offset(y: -34 + float * 0.4)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.8))
                .frame(width: 276, height: 190)
                .shadow(color: .black.opacity(0.07), radius: 22, y: 10)
                .offset(y: -18 + float * 0.7)

            card
                .offset(y: float)
                .rotationEffect(.degrees(sway))
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Text("🩹").font(.system(size: 12))
                    Text("BPC-157")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color(hex: 0xE9E9E9).opacity(0.6), in: Capsule())
                Spacer()
                Text("2h").pepText(.footnote, Ink.hint)
            }

            Text("Does BPC-157 actually help tendon healing?")
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.57)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text("The evidence is promising but mostly preclinical — here's what the studies actually show…")
                .pepText(.footnote, Ink.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(hex: 0xDFDFDF))
                    Text("SC")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                }
                .frame(width: 24, height: 24)

                Text("Dr. Sarah Chen").pepText(.caption)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Accent.info)

                Spacer()
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(width: 300)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 30, y: 14)
    }

    private func bubble(_ emoji: String, _ size: CGFloat, _ hex: UInt,
                        x: CGFloat, y: CGFloat, t: Double, phase: Double) -> some View {
        ZStack {
            Circle().fill(Color(hex: hex).opacity(0.85))
            Text(emoji).font(.system(size: size * 0.5))
        }
        .frame(width: size, height: size)
        .offset(x: x, y: y + (reduceMotion ? 0 : 4 * sin(t * 0.4 + phase)))
    }
}

#Preview {
    QuestionHero()
        .frame(height: 348)
}
