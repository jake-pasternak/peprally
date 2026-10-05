import SwiftUI
import AuthenticationServices

/// The auth poster — the *only* signed-out surface. A deck of real question
/// cards shuffles at the top, then one claim, one whisper line, one action.
///
/// There is deliberately no sign-up / sign-in split, and no second method.
/// "Continue with Apple" is both: Apple returns a token for the same Apple ID
/// every time, so a returning user lands back on their existing account and
/// `handleAppleSignIn` routes them home while a new one goes to setup. One
/// identity per person, one button, nothing to remember.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false
    @State private var appleCoordinator = AppleSignInCoordinator()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                QuestionDeck()
                    .frame(maxHeight: 430)
                    .entrance(appeared, delay: 0.1, blur: false)

                Spacer()

                Text("The most accurate place to learn about peptides.")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.52)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 27)
                    .padding(.trailing, 80)
                    .entrance(appeared, delay: 0.25)

                Text("Vetted answers · answer anything · scientific evidence")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(-0.13)
                    .foregroundStyle(Ink.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 27)
                    .padding(.top, 12)
                    .entrance(appeared, delay: 0.35)

                Spacer()

                Button {
                    #if DEMO
                    // the demo build has no Sign in with Apple entitlement, so
                    // the real flow can only fail — sign in walks straight to
                    // the feed, which also means signing out can't strand you
                    model.enterDemo()
                    return
                    #endif
                    appleCoordinator.onResult = { result in
                        switch result {
                        case .success(let r):
                            Task { await model.handleAppleSignIn(idToken: r.idToken, nonce: r.nonce) }
                        case .failure(let error):
                            if (error as? ASAuthorizationError)?.code != .canceled {
                                model.authError = error.localizedDescription
                            }
                        }
                    }
                    appleCoordinator.start()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16))
                        Text("Continue with Apple")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.32)
                    .foregroundStyle(Ink.onDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Fill.charcoal, in: Capsule())
                    .contentShape(Capsule())
                }
                .padding(.horizontal, 20)
                .entrance(appeared, delay: 0.45)

                Text("Educational discussion only — not medical advice. By continuing you agree to our [Terms](https://peprally.xyz/terms) and [Privacy Policy](https://peprally.xyz/privacy)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.hint)
                    .tint(Ink.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .entrance(appeared, delay: 0.65)
            }
            .padding(.bottom, 16)
        }
        .onAppear { appeared = true }
        .alert("Couldn't sign in", isPresented: Binding(
            get: { model.authError != nil },
            set: { if !$0 { model.authError = nil } })) {
            Button("OK") {}
        } message: {
            Text(model.authError ?? "")
        }
    }
}

/// The floating deck, event-driven: no per-frame clock. The idle float is
/// one repeat-forever animation; every few seconds a task fires two spring
/// keyframes — the front card swings out right and tucks in at the back as
/// the stack steps forward. Cards render at true size, crisp.
private struct QuestionDeck: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cycle = 0
    @State private var leaving: Int? = nil
    @State private var leavingX: CGFloat = 0
    @State private var floating = false

    private struct Q {
        let chip: String
        let time: String
        let title: String
        let preview: String
        let initials: String
        let avatarHex: UInt
        let author: String
        let badge: TrustBadge?
    }

    private static let questions: [Q] = [
        Q(chip: "BPC-157", time: "2h",
          title: "Does BPC-157 actually help tendon healing?",
          preview: "The evidence is promising but mostly preclinical — here's what the studies actually show…",
          initials: "SC", avatarHex: 0xDFDFDF, author: "Dr. Sarah Chen",
          badge: .verified(credential: "Physician")),
        Q(chip: "Semaglutide", time: "5h",
          title: "How are you handling week-one semaglutide nausea?",
          preview: "Smaller meals and slower titration made the difference for me. What worked for everyone else…",
          initials: "GJ", avatarHex: 0xEAEAEA, author: "glp1journey",
          badge: nil),
        Q(chip: "NAD+", time: "9h",
          title: "Is sublingual NAD+ absorption actually meaningful?",
          preview: "Bioavailability studies suggest most of it never makes it past first-pass metabolism…",
          initials: "MW", avatarHex: 0xD8D8D8, author: "Dr. Marcus Webb",
          badge: .verified(credential: "Pharmacology PhD")),
    ]

    var body: some View {
        GeometryReader { geo in
            let k = min((geo.size.width - 64) / 360, (geo.size.height - 76) / 250, 1)
            ZStack {
                ForEach(0..<3, id: \.self) { i in deckCard(i, k: k) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: floating ? -4 : 4)
            .animation(reduceMotion ? nil
                       : .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                       value: floating)
        }
        .onAppear {
            floating = true
            guard !reduceMotion else { return }
            Task { await shuffleLoop() }
        }
    }

    private func shuffleLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4.2))
            let front = ((cycle % 3) + 3) % 3
            leaving = front
            withAnimation(.easeIn(duration: 0.38)) { leavingX = 460 }
            try? await Task.sleep(for: .seconds(0.38))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                cycle += 1
                leavingX = 0
            }
            try? await Task.sleep(for: .seconds(0.6))
            leaving = nil
        }
    }

    private func slot(_ i: Int) -> Int { (((i - cycle) % 3) + 3) % 3 }

    private func deckCard(_ i: Int, k: CGFloat) -> some View {
        let s = slot(i)
        let ys: [CGFloat] = [0, -22 * k, -41 * k]
        let scales: [CGFloat] = [1, 0.92, 0.84]
        let isLeaving = leaving == i

        return card(Self.questions[i], slot: s, k: k)
            .scaleEffect(scales[s])
            .rotationEffect(.degrees(isLeaving && leavingX > 0 ? 7 : 0))
            .offset(x: isLeaving ? leavingX : 0, y: ys[s])
            .zIndex(isLeaving && s != 0 ? 0.5 : Double(3 - s))
            .animation(Motion.select, value: s)
    }

    /// Front card: white with a hairline border and soft shadow. Ghost
    /// cards behind: light gray blocks (white-on-white would vanish).
    private func card(_ q: Q, slot: Int, k: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(q.chip)
                    .font(.system(size: 13 * k, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                    .padding(.horizontal, 12 * k)
                    .frame(height: 31 * k)
                    .background(Fill.regular, in: Capsule())
                Spacer()
                Text(q.time)
                    .font(.system(size: 14 * k, weight: .medium))
                    .foregroundStyle(Ink.hint)
            }

            Text(q.title)
                .font(.system(size: 23 * k, weight: .bold))
                .tracking(-0.69 * k)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16 * k)

            Text(q.preview)
                .font(.system(size: 14 * k, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9 * k)

            Spacer(minLength: 0)

            HStack(spacing: 9 * k) {
                ZStack {
                    Circle().fill(Color(hex: q.avatarHex))
                    Text(q.initials)
                        .font(.system(size: 12 * k, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                }
                .frame(width: 29 * k, height: 29 * k)

                Text(q.author)
                    .font(.system(size: 15 * k, weight: .medium))
                    .tracking(-0.15 * k)
                    .foregroundStyle(Ink.primary)
                if let badge = q.badge {
                    TrustBadgeView(badge: badge, compact: true)
                }
                Spacer()
            }
        }
        .opacity(slot == 0 ? 1 : 0)
        .padding(24 * k)
        .frame(width: 360 * k, height: 250 * k)
        .background(
            RoundedRectangle(cornerRadius: 28 * k, style: .continuous)
                .fill(slot == 0 ? Color.white : Color.black.opacity(0.04))
                .shadow(color: .black.opacity(slot == 0 ? 0.10 : 0),
                        radius: 24 * k, y: 12 * k)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28 * k, style: .continuous)
                .strokeBorder(Color.black.opacity(slot == 0 ? 0.07 : 0), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView().environment(AppModel())
}
