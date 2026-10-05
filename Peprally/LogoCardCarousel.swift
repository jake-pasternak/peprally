import SwiftUI

/// The onboarding hero: a single large rounded card centered with generous
/// margin, playing the peprally mark. Cards dwell, then glide to the next.
///
/// Fully native and deliberately cheap: the animation is a bundled frame
/// sequence decoded once — every card shares the same texture, and all
/// motion is a single offset driven by TimelineView. No video decoders,
/// no web view, nothing that can stutter.
struct LogoCardCarousel: View {
    private let dwell: Double = 3.6          // seconds a card rests centered
    private let slide: Double = 0.9          // seconds of glide between cards
    private let cardWidthRatio: Double = 0.62

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let frame = LogoFrames.frame(at: t)

                let W = geo.size.width
                let H = geo.size.height
                let cardW = W * cardWidthRatio
                let cardH = H * 0.92

                // dwell ... toss ... dwell: fract eases 0 -> 1 with a soft
                // overshoot (the settle wobble from the reference)
                let period = dwell + slide
                let u = (t.truncatingRemainder(dividingBy: period))
                let g = max(0, (u - dwell) / slide)
                let c1 = 1.35, c3 = c1 + 1
                let fract = g == 0 ? 0
                    : 1 + c3 * pow(g - 1, 3) + c1 * pow(g - 1, 2)

                // three live cards: the one leaving (d 0), arriving (d -1),
                // and on deck (d -2); p = 0 is rest, +1 gone up-right
                ZStack {
                    ForEach([0, -1, -2], id: \.self) { d in
                        let p = Double(d) + fract
                        card(frame: frame, width: cardW, height: cardH)
                            .scaleEffect(1 - 0.07 * p)
                            .rotationEffect(.degrees(26 * p))
                            .offset(x: CGFloat(p) * W * 0.98,
                                    y: CGFloat(p) * -H * 0.42)
                    }
                }
                .frame(width: W, height: H)
            }
        }
        .clipped()
    }

    private func card(frame: UIImage?, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04)
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

#Preview {
    LogoCardCarousel()
        .frame(height: 372)
}
