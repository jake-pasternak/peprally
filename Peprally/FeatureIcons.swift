import SwiftUI

/// The animated icons for the signup feature card — the original SF
/// Symbols on a shared 6-second clock, each performing its own verb in
/// sequence: the tick ticks (0.4s), the lens presses in (2.0s), the
/// question bubble wonders (4.2s). Outside its window each icon is the
/// untouched original, so a paused clock (Reduce Motion) is the static card.

// MARK: - Easing

private func seg(_ t: Double, _ a: Double, _ b: Double) -> Double {
    guard b > a else { return t >= b ? 1 : 0 }
    let x = min(1, max(0, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)
}

/// 0→1→0 bump over [a, b]
private func bump(_ t: Double, _ a: Double, _ b: Double) -> Double {
    guard b > a else { return 0 }
    let x = min(1, max(0, (t - a) / (b - a)))
    return sin(.pi * x)
}

private func lerp(_ a: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
}

// MARK: - Vetted answers · the seal ticks

struct TickIcon: View {
    let t: Double

    var body: some View {
        let dip  = bump(t, 0.40, 0.66)
        let land = bump(t, 0.64, 1.05)
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 24, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Accent.info)
            .scaleEffect(1 - 0.16 * dip + 0.10 * land)
            .rotationEffect(.degrees(-14 * dip + 6 * land))
    }
}

// MARK: - Evidence-graded · the lens presses in to inspect

struct SearchIcon: View {
    let t: Double

    var body: some View {
        // a focus press: leans toward the lens corner, settles back with
        // a small overshoot — same family as the tick's snap
        let press = bump(t, 2.00, 2.28)
        let land  = bump(t, 2.26, 2.70)
        Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 24, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Accent.success)
            .scaleEffect(1 - 0.12 * press + 0.08 * land)
            .rotationEffect(.degrees(9 * press - 4 * land))
    }
}

// MARK: - Ask anything · the bubble wonders

struct AskIcon: View {
    let t: Double

    var body: some View {
        let local = t - 4.2
        let u = min(1, max(0, local / 1.1))
        // a decaying head-tilt wobble with a small pop at the start
        let wobble = u == 0 || u == 1 ? 0 : sin(u * .pi * 3) * (1 - u) * 9
        let pop = 1 + 0.10 * bump(local, 0.0, 0.4)

        Image(systemName: "questionmark.bubble.fill")
            .font(.system(size: 24, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Accent.ask)
            .scaleEffect(pop)
            .rotationEffect(.degrees(wobble))
    }
}

#Preview {
    TimelineView(.animation) { context in
        let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6)
        VStack(spacing: 24) {
            TickIcon(t: t)
            SearchIcon(t: t)
            AskIcon(t: t)
        }
        .padding()
        .background(Color.black.opacity(0.025))
    }
}
