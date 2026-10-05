import SwiftUI

/// Staggered load-in: each section blurs into focus while rising, on a
/// soft spring — one after the next. Shared by the welcome pages.
struct Entrance: ViewModifier {
    let shown: Bool
    let delay: Double
    /// static text blocks blur into focus; pass false for surfaces that
    /// are themselves animating (a live blur over live content is jank)
    var blur: Bool = true

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .blur(radius: shown || !blur ? 0 : 7)
            .animation(.spring(response: 0.95, dampingFraction: 0.9).delay(delay), value: shown)
    }
}

extension View {
    func entrance(_ shown: Bool, delay: Double, blur: Bool = true) -> some View {
        modifier(Entrance(shown: shown, delay: delay, blur: blur))
    }
}

/// Feed-card load-in — livelier than `Entrance`: each card rises, scales up
/// from its top edge and unblurs on a snappy spring, staggered down the whole
/// list (not capped), so the feed *assembles* with a little pop instead of a
/// slow uniform fade.
struct CardEntrance: ViewModifier {
    let shown: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.95, anchor: .top)
            .offset(y: shown ? 0 : 24)
            .blur(radius: shown ? 0 : 5)
            .animation(.spring(response: 0.52, dampingFraction: 0.76)
                .delay(0.04 + Double(index) * 0.06), value: shown)
    }
}

extension View {
    func cardEntrance(_ shown: Bool, index: Int) -> some View {
        modifier(CardEntrance(shown: shown, index: index))
    }
}
