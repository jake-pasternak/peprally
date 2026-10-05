import SwiftUI

/// Applying to moderate — a volunteer community role, judged on track
/// record and judgment, NOT on credentials. Deliberately separate from
/// professional verification: a clinician and a sharp non-professional are
/// equally eligible. Three faces: the role (with an eligibility gate), the
/// application form, and the in-review state. Presented from Settings;
/// never blocks anything.
struct ModApplyFlow: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void

    @State private var step: Step = .intro
    @State private var reason = ""
    @State private var commitment: Commitment?
    @State private var agreed = false

    enum Step { case intro, application, review }

    enum Commitment: String, CaseIterable, Identifiable {
        case light   = "A few hours"
        case regular = "Most days"
        case daily   = "Daily"
        var id: String { rawValue }
    }

    // mock eligibility — the backend will compute this from account age and
    // standing. Both criteria met so the happy path is demoable.
    private let memberLongEnough = true
    private let inGoodStanding = true
    private var eligible: Bool { memberLongEnough && inGoodStanding }

    var body: some View {
        ZStack {
            switch step {
            case .intro:       intro
            case .application: application
            case .review:      review
            }
        }
        .background(Color.white.ignoresSafeArea())
        .tint(Ink.secondary)
        .onAppear {
            // dev hook: MOD_STEP=application|review jumps to a later face
            switch ProcessInfo.processInfo.environment["MOD_STEP"] {
            case "application": step = .application
            case "review":      step = .review
            default:            break
            }
        }
    }

    // MARK: - Step 1 · the role + eligibility gate

    private var intro: some View {
        StepScaffold(onBack: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                FlowTitle(title: "Become a moderator",
                          subtitle: "Help keep the rally healthy. A volunteer role — it's about judgment and track record, not a credential.")

                section("WHAT MODERATORS DO").padding(.top, Space.x2l)
                VStack(alignment: .leading, spacing: Space.md) {
                    duty("flag", "Review reports and flagged posts")
                    duty("bubble.left.and.exclamationmark.bubble.right", "Keep threads civil and on-topic")
                    duty("book.closed", "Apply the Community Guidelines, consistently")
                }
                .padding(.top, Space.md)

                section("ELIGIBILITY").padding(.top, Space.x2l)
                VStack(alignment: .leading, spacing: Space.sm) {
                    criterion("Member for 30+ days", met: memberLongEnough)
                    criterion("In good standing — no recent strikes", met: inGoodStanding)
                }
                .padding(.top, Space.md)
            }
        } footer: {
            VStack(spacing: Space.sm) {
                Button("Apply to moderate") {
                    withAnimation(Motion.fast) { step = .application }
                }
                .buttonStyle(.pepPrimary)
                .disabled(!eligible)

                Button("Not now") { onClose() }
                    .buttonStyle(.pepGhost)
            }
        }
    }

    private func duty(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .frame(width: 26)
            Text(text).pepText(.label, Ink.primary)
            Spacer(minLength: 0)
        }
    }

    private func criterion(_ text: String, met: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(met ? Accent.success : Ink.hint)
            Text(text).pepText(.footnote, met ? Ink.primary : Ink.tertiary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 2 · the application

    private var canSubmit: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && commitment != nil && agreed
    }

    private var application: some View {
        StepScaffold(onBack: { withAnimation(Motion.fast) { step = .intro } }) {
            VStack(alignment: .leading, spacing: 0) {
                FlowTitle(title: "Your application",
                          subtitle: "A real person on the mod team reads every one.")

                section("WHY DO YOU WANT TO HELP MODERATE?").padding(.top, Space.x2l)
                TextField("", text: $reason,
                          prompt: Text("A sentence or two — what draws you to it, and what you'd bring.")
                            .foregroundStyle(Ink.hint),
                          axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(3...7)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Fill.subtle, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .padding(.top, Space.md)

                section("HOW MUCH TIME CAN YOU GIVE?").padding(.top, Space.x2l)
                HStack(spacing: Space.sm) {
                    ForEach(Commitment.allCases) { c in
                        commitmentChip(c)
                    }
                }
                .padding(.top, Space.md)

                agreeRow.padding(.top, Space.x2l)
            }
        } footer: {
            Button("Submit application") {
                // TODO: persist the application to the mod-review queue
                model.modApplicationPending = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(Motion.fast) { step = .review }
            }
            .buttonStyle(.pepPrimary)
            .disabled(!canSubmit)
        }
    }

    private func commitmentChip(_ c: Commitment) -> some View {
        let selected = commitment == c
        return Button {
            withAnimation(Motion.select) { commitment = c }
        } label: {
            Text(c.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? Ink.onDark : Ink.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selected ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.regular),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var agreeRow: some View {
        Button { withAnimation(Motion.select) { agreed.toggle() } } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(agreed ? Ink.primary : Ink.hint)
                (Text("I've read and agree to uphold the ")
                 + Text("Community Guidelines").underline())
                    .pepText(.footnote, Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3 · in review

    private var review: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.16))

            Text("Application received")
                .pepText(.title)
                .padding(.top, Space.x2l)

            Text("The mod team reviews new applications every week.\nWe'll message you either way — keep using the rally.")
                .pepText(.label, Ink.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, Space.md)

            Spacer()

            Button("Done") { onClose() }
                .buttonStyle(.pepGhost)
                .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.margin)
    }

    // MARK: - pieces

    private func section(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Ink.tertiary)
    }
}

/// Shared chrome for the two scrolling steps: a back chip, scrollable body,
/// and a pinned footer of actions.
private struct StepScaffold<Body: View, Footer: View>: View {
    var onBack: () -> Void
    @ViewBuilder var content: () -> Body
    @ViewBuilder var footer: () -> Footer
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PepBackChip(action: onBack)
                Spacer()
            }
            .padding(.top, Space.md)

            ScrollView {
                content()
                    .padding(.bottom, Space.x2l)
                    .entrance(appeared, delay: 0, blur: false)
            }
            .scrollIndicators(.hidden)

            footer()
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
                .entrance(appeared, delay: 0.08, blur: false)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }
}

private struct FlowTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).pepText(.display)
            Text(subtitle)
                .pepText(.body, Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.x2l)
    }
}

#Preview {
    ModApplyFlow(onClose: {}).environment(AppModel())
}
