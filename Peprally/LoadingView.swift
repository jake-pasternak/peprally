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

#Preview {
    LoadingView()
}
