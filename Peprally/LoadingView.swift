import SwiftUI

/// The loading screen: white, with the eight dots built in black — the four
/// arms of the plus pop in one at a time in clock order (12 → 3 → 6 → 9),
/// each with a small landing pop (see MarkView `.clock`). Black and white,
/// nothing else.
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white
            MarkView(color: .black, style: .clock, startDelay: 0.2)
                .frame(width: 84, height: 84)
        }
        .ignoresSafeArea()
    }
}

/// The p glyph, kept for reference — retired from the running app when
/// the brand consolidated on the dot mark.
struct PGlyph: View {
    var blink: CGFloat = 0
    var color: Color = .white
    var eyeColor: Color = Color(hex: 0x5B3E93)

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 100
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(color)
                    .frame(width: 12 * k, height: 58 * k)
                    .offset(x: 31 * k, y: 22 * k)
                Circle()
                    .fill(color)
                    .frame(width: 42 * k, height: 42 * k)
                    .offset(x: 34 * k, y: 27 * k)
                ForEach([49.0, 61.0], id: \.self) { cx in
                    Ellipse()
                        .fill(eyeColor)
                        .frame(width: 7.2 * k, height: 10.4 * k)
                        .scaleEffect(y: max(0.08, 1 - blink), anchor: .center)
                        .offset(x: (cx - 3.6) * k, y: (46 - 5.2) * k)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    LoadingView()
}
