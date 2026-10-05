import SwiftUI

/// The 8-dot mark as a progress meter — the brand IS the mechanic.
/// Dots light in the formation order (bottom-up, like the loading wave)
/// as `lit` climbs 0...8. Used by hold-to-vouch and anywhere trust is
/// handed over.
struct DotMeter: View {
    var lit: Int
    var color: Color = Ink.primary
    var dimOpacity: Double = 0.22

    // dot centers matching the app icon (see MarkView / node 429:2)
    private static let raw: [CGPoint] = [
        .init(x: 511.5, y: 334.5), .init(x: 511.5, y: 393.5),
        .init(x: 334.5, y: 511.5), .init(x: 393.5, y: 511.5),
        .init(x: 629.5, y: 511.5), .init(x: 688.5, y: 511.5),
        .init(x: 511.5, y: 629.5), .init(x: 511.5, y: 688.5),
    ]
    private static let dotR: CGFloat = 19.5
    private static let clusterMin: CGFloat = 334.5 - dotR
    private static let clusterSpan: CGFloat = (688.5 + dotR) - (334.5 - dotR)
    /// fill order: bottom arm first, rising to the top — the formation
    private static let fillRank: [Int] = [7, 6, 5, 4, 3, 2, 1, 0]

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = Self.dotR / Self.clusterSpan * s
            ZStack(alignment: .topLeading) {
                ForEach(0..<Self.raw.count, id: \.self) { i in
                    let p = Self.raw[i]
                    let isLit = Self.fillRank[i] < lit
                    Circle()
                        .fill(color)
                        .opacity(isLit ? 1 : dimOpacity)
                        .frame(width: r * 2, height: r * 2)
                        .scaleEffect(isLit ? 1 : 0.8)
                        .position(x: (p.x - Self.clusterMin) / Self.clusterSpan * s,
                                  y: (p.y - Self.clusterMin) / Self.clusterSpan * s)
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: lit)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    HStack(spacing: 20) {
        DotMeter(lit: 0).frame(width: 24)
        DotMeter(lit: 4).frame(width: 24)
        DotMeter(lit: 8).frame(width: 24)
    }
    .padding()
}
