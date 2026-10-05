import SwiftUI
import UserNotifications

/// The post-auth setup flow: four light steps, shared chrome, driven by
/// AppModel.stage so an interrupted user resumes where they left off.
struct SetupFlowView: View {
    @Environment(AppModel.self) private var model
    let step: SetupStep

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.md)

            Group {
                switch step {
                case .handle:        HandleStep()
                case .peptides:      PeptidesStep()
                case .professional:  ProfessionalStep()
                case .notifications: NotificationsStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(step)
        }
        .background(Color.white)
    }

    private var header: some View {
        ZStack {
            // progress as the brand's dots
            HStack(spacing: 7) {
                ForEach(SetupStep.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Ink.primary : Fill.strong)
                        .frame(width: 7, height: 7)
                }
            }
            HStack {
                Button {
                    model.backSetup(from: step)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.secondary.opacity(step == .handle ? 0 : 1))
                        .frame(width: 44, height: 44)
                }
                .disabled(step == .handle)
                Spacer()
            }
        }
        .frame(height: 44)
    }
}

// MARK: - Shared pieces

private struct StepTitle: View {
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
    }
}

// MARK: - Step 1 · handle

private struct HandleStep: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false
    @State private var status: Status = .idle
    @State private var checkTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    enum Status { case idle, checking, available, taken }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "Claim your handle",
                      subtitle: "This is how the rally knows you")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0)

            HStack(spacing: 2) {
                Text("@")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Ink.hint)
                TextField("", text: $model.handle,
                          prompt: Text("handle").foregroundStyle(Ink.hint))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .font(.system(size: 16, weight: .medium))
                    .onChange(of: model.handle) { _, new in
                        let clean = String(new.lowercased()
                            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            .prefix(20))
                        if clean != model.handle { model.handle = clean }
                        scheduleCheck(clean)
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: Metrics.input)
            .background(Fill.regular,
                        in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .padding(.top, Space.x2l)
            .entrance(appeared, delay: 0.12)

            statusLine
                .padding(.top, Space.sm)
                .padding(.horizontal, 4)

            Spacer()

            Button("Continue") { model.advanceSetup(from: .handle) }
                .buttonStyle(.pepPrimary)
                .disabled(status != .available)
                .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true; focused = true }
    }

    @ViewBuilder private var statusLine: some View {
        switch status {
        case .idle:
            Color.clear.frame(height: 17)
        case .checking:
            Text("Checking…").pepText(.footnote, Ink.tertiary)
        case .available:
            Label("@\(model.handle) is available", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Accent.success)
        case .taken:
            Label("That handle is taken", systemImage: "xmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.secondary)
        }
    }

    /// Debounced availability check — waits for a typing pause, then queries.
    private func scheduleCheck(_ handle: String) {
        checkTask?.cancel()
        guard handle.count >= 3 else { status = .idle; return }
        status = .checking
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            let ok = await ProfileService.isHandleAvailable(handle)
            if Task.isCancelled { return }
            status = ok ? .available : .taken
        }
    }
}

// MARK: - Step 2 · peptides

private struct PeptidesStep: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    private struct Peptide { let name: String; let icon: String; let hex: UInt }
    private struct Category { let title: String; let items: [Peptide] }

    /// starter topics, grouped by what they're for — line-icon visuals,
    /// no emoji, on the hero wall's pastels
    private static let categories: [Category] = [
        Category(title: "Recovery & repair", items: [
            Peptide(name: "BPC-157", icon: "bandage.fill", hex: 0xE9E9E9),
            Peptide(name: "TB-500", icon: "figure.strengthtraining.traditional", hex: 0xEBEBEB),
            Peptide(name: "GHK-Cu", icon: "sparkles", hex: 0xEAEAEA),
            Peptide(name: "Thymosin α-1", icon: "shield.lefthalf.filled", hex: 0xE9E9E9),
        ]),
        Category(title: "Weight & metabolic", items: [
            Peptide(name: "Semaglutide", icon: "arrow.down.forward.circle.fill", hex: 0xDFDFDF),
            Peptide(name: "Tirzepatide", icon: "chart.line.downtrend.xyaxis", hex: 0xEAEAEA),
            Peptide(name: "Retatrutide", icon: "fork.knife", hex: 0xE8E8E8),
            Peptide(name: "MOTS-c", icon: "figure.run", hex: 0xEBEBEB),
        ]),
        Category(title: "Growth & performance", items: [
            Peptide(name: "CJC-1295", icon: "chart.line.uptrend.xyaxis", hex: 0xE9E9E9),
            Peptide(name: "Ipamorelin", icon: "moon.zzz.fill", hex: 0xD8D8D8),
        ]),
        Category(title: "Longevity", items: [
            Peptide(name: "NAD+", icon: "bolt.fill", hex: 0xDFDFDF),
            Peptide(name: "Epithalon", icon: "hourglass", hex: 0xE8E8E8),
        ]),
    ]

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "Follow your peptides",
                      subtitle: "This is what your feed is made of — pick at least one")
                .padding(.top, Space.x2l)
                .padding(.horizontal, Space.margin)
                .entrance(appeared, delay: 0)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.x2l) {
                    ForEach(Array(Self.categories.enumerated()), id: \.offset) { ci, cat in
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text(cat.title.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.55)
                                .foregroundStyle(Ink.tertiary)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(cat.items, id: \.name) { item in tile(item) }
                            }
                        }
                        .entrance(appeared, delay: 0.1 + 0.06 * Double(ci))
                    }
                }
                .padding(.horizontal, Space.margin)
                .padding(.top, Space.x2l)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            Button(model.followedPeptides.isEmpty
                   ? "Continue"
                   : "Continue with \(model.followedPeptides.count)") {
                model.advanceSetup(from: .peptides)
            }
            .buttonStyle(.pepPrimary)
            .disabled(model.followedPeptides.isEmpty)
            .padding(.horizontal, Space.margin)
            .padding(.bottom, Space.lg)
        }
        .onAppear { appeared = true }
    }

    private func tile(_ item: Peptide) -> some View {
        let selected = model.followedPeptides.contains(item.name)
        return Button {
            withAnimation(Motion.select) {
                if selected { model.followedPeptides.remove(item.name) }
                else { model.followedPeptides.insert(item.name) }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(selected ? Ink.onDark : Ink.primary)
                Text(item.name)
                    .pepText(.footnote, selected ? Ink.onDark : Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(selected ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.subtle),
                        in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
    }
}

// MARK: - Step 3 · professional

private struct ProfessionalStep: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false
    @State private var choice: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "Are you a healthcare professional?",
                      subtitle: "Professionals can get verified — a badge that tells the rally an answer comes from someone who knows")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0)

            VStack(spacing: Space.sm) {
                card("stethoscope", "I'm a professional",
                     "Doctor, researcher or clinician", value: true)
                    .entrance(appeared, delay: 0.12)
                card("book", "I'm here to learn",
                     "Questions, experiences, lurking — all good", value: false)
                    .entrance(appeared, delay: 0.2)
            }
            .padding(.top, Space.x2l)

            Spacer()

            Button("Continue") {
                model.isProfessional = choice ?? false
                model.advanceSetup(from: .professional)
            }
            .buttonStyle(.pepPrimary)
            .disabled(choice == nil)
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }

    private func card(_ symbol: String, _ title: String, _ subtitle: String, value: Bool) -> some View {
        let selected = choice == value
        return Button {
            withAnimation(Motion.select) { choice = value }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? Ink.onDark : Ink.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).pepText(.label, selected ? Ink.onDark : Ink.primary)
                    Text(subtitle).pepText(.footnote, selected ? Ink.onDarkSecondary : Ink.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, Space.lg)
            .background(selected ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.subtle),
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }
}

// MARK: - Step 4 · notifications

private struct NotificationsStep: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "Know when you get answers",
                      subtitle: "One notification when someone answers your question or mentions you — nothing else")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0)

            // a lock-screen preview — the exact two kinds of alert this
            // permission controls, dropping in one after another so the
            // page reads as "here's what you'll get"
            notificationPreview
                .padding(.top, Space.x2l)

            // reassurance before the system prompt — what we'll never send
            reassurance
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0.44, blur: false)

            Spacer(minLength: Space.lg)

            VStack(spacing: Space.sm) {
                Button("Enable notifications") {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                        model.advanceSetup(from: .notifications)
                    }
                }
                .buttonStyle(.pepPrimary)

                Button("Not now") {
                    model.advanceSetup(from: .notifications)
                }
                .buttonStyle(.pepGhost)
            }
            .padding(.bottom, Space.lg)
            .entrance(appeared, delay: 0.5)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }

    // the three preview notifications — all answers or mentions, nothing else
    private static let previews: [(body: String, time: String, initials: String, hex: UInt)] = [
        ("Dr. Chen answered your question about BPC-157", "now", "SC", 0xDFDFDF),
        ("@sarahchen mentioned you in TB-500", "2m", "SC", 0xDFDFDF),
        ("tendonrehab answered “Does BPC-157 help tendon healing?”", "5m", "TR", 0xEAEAEA),
    ]

    private var notificationPreview: some View {
        VStack(spacing: 10) {
            ForEach(Array(Self.previews.enumerated()), id: \.offset) { i, n in
                notification(n.body, time: n.time, initials: n.initials, hex: n.hex)
                    .offset(y: dropped ? 0 : -12)
                    .opacity(dropped ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8)
                        .delay(0.35 + 0.09 * Double(i)), value: dropped)
            }
        }
        .onAppear { dropped = true }
    }

    @State private var dropped = false

    private var reassurance: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            promise("bell.badge", "Only answers and mentions")
            promise("nosign", "No marketing, ever")
            promise("slider.horizontal.3", "Turn it off anytime in Settings")
        }
    }

    private func promise(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .frame(width: 22)
            Text(text).pepText(.footnote, Ink.secondary)
        }
    }

    private func notification(_ body: String, time: String, initials: String, hex: UInt) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: hex))
                Text(initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Peprally").pepText(.caption)
                    Spacer()
                    Text(time).pepText(.footnote, Ink.hint)
                }
                Text(body)
                    .pepText(.footnote, Ink.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
}

#Preview {
    SetupFlowView(step: .peptides).environment(AppModel())
}
