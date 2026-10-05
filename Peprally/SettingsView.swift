import SwiftUI

/// Settings, opened from the gear on the profile. Grouped cards in the
/// dots' quiet language. Toggles persist via AppStorage; navigation rows
/// push a simple detail; legal rows open the site; sign out and delete
/// live at the bottom. Backend-dependent actions are marked.
struct SettingsView: View {
    /// The product version, deliberately not `CFBundleShortVersionString`. The
    /// App Store record is inherited from Compound+, whose approved history
    /// forces the bundle's MARKETING_VERSION to 5.x. As a product this is
    /// peprally+ 1.0, and that's what a person in Settings should read.
    private static let displayVersion = "1.0"

    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    // real, persisted preferences
    @AppStorage("settings.pushReplies") private var pushReplies = true
    @AppStorage("settings.pushMentions") private var pushMentions = true
    @AppStorage("settings.pushWeekly") private var pushWeekly = false
    @AppStorage("settings.showNSFW") private var showNSFW = false
    @AppStorage("settings.haptics") private var haptics = true

    @State private var appeared = false
    @State private var detail: Detail?
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var showModApply = false

    enum Detail: String, Identifiable {
        case notifications = "Notifications"
        case blocked = "Blocked accounts"
        var id: String { rawValue }
    }

    private var handle: String { model.handle.isEmpty ? "jake" : model.handle }

    var body: some View {
        ZStack {
            settingsFace
                .opacity(detail == nil ? 1 : 0)

            if let d = detail {
                detailScreen(d)
                    .transition(.opacity)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .confirmationDialog("Sign out of peprally+?", isPresented: $showSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { model.signOut() }
        } message: {
            // the fear at this button is "will I lose my account" — Apple hands
            // back the same identity every time, so say so plainly
            Text("Your account stays exactly as it is. Continue with Apple to sign back in.")
        }
        .alert("Delete account", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                model.deleteAccount()
            }
        } message: {
            Text("This permanently removes your account, questions, and answers. This can't be undone.")
        }
        .fullScreenCover(isPresented: $showModApply) {
            ModApplyFlow(onClose: { showModApply = false })
        }
    }

    // MARK: root

    private var settingsFace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PepBackChip(action: onBack)
                    .padding(.top, Space.md)

                Text("Settings")
                    .pepText(.display)
                    .padding(.top, Space.lg)
                    .entrance(appeared, delay: 0, blur: false)

                // ACCOUNT
                group("ACCOUNT", delay: 0.06) {
                    infoRow("Username", "@\(handle)")
                    divider
                    infoRow("Phone", model.phone.isEmpty ? "Not set" : model.phone)
                    divider
                    if model.isProfessional {
                        navRow("Verification",
                               value: model.verificationPending ? "In review" : "Verified") {
                            model.advanceVerify(to: .intro)
                        }
                    } else {
                        navRow("Get verified", value: nil) { model.advanceVerify(to: .intro) }
                    }
                }

                // PREFERENCES
                group("PREFERENCES", delay: 0.12) {
                    pushRow("Notifications", value: pushReplies || pushMentions ? "On" : "Off") {
                        detail = .notifications
                    }
                    divider
                    toggleRow("Haptics", isOn: $haptics)
                    divider
                    toggleRow("Show sensitive content", isOn: $showNSFW)
                }

                // SAFETY
                group("SAFETY", delay: 0.18) {
                    navRow("Blocked accounts", value: nil) {
                        detail = .blocked
                        if SampleData.on {
                            blocked = SampleData.blocked
                        } else {
                            Task { blocked = await BlockService.myBlocked() }
                        }
                    }
                    divider
                    if model.isModerator {
                        infoRow("Role", "Moderator")
                    } else if model.modApplicationPending {
                        infoRow("Moderator application", "In review")
                    } else {
                        navRow("Apply to moderate", value: nil) { showModApply = true }
                    }
                    divider
                    linkRow("Community Guidelines", url: "https://peprally.xyz/guidelines")
                }

                // ABOUT
                group("ABOUT", delay: 0.24) {
                    linkRow("Terms of Service", url: "https://peprally.xyz/terms")
                    divider
                    linkRow("Privacy Policy", url: "https://peprally.xyz/privacy")
                    divider
                    linkRow("Help & support", url: "https://peprally.xyz/help")
                }

                // account actions
                VStack(spacing: Space.sm) {
                    Button("Sign out") { showSignOut = true }
                        .buttonStyle(.pepGhost)
                    Button("Delete account") { showDelete = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Accent.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.control)
                }
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0.3, blur: false)

                VStack(spacing: 10) {
                    Text("For educational discussion only. Not medical advice — consult a licensed healthcare professional before making any health decision.")
                        .pepText(.footnote, Ink.hint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("peprally+ \(Self.displayVersion)")
                        .pepText(.footnote, Ink.hint)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Space.md)
                .padding(.bottom, Space.x2l)
                .entrance(appeared, delay: 0.3, blur: false)
            }
            .padding(.horizontal, Space.xl)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            appeared = true
            // dev hook: MOD_APPLY=1 opens the moderator application directly
            if ProcessInfo.processInfo.environment["MOD_APPLY"] != nil {
                showModApply = true
            }
        }
    }

    // MARK: detail screens

    @ViewBuilder
    private func detailScreen(_ d: Detail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { withAnimation(Motion.fast) { detail = nil } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Ink.primary)
                            .frame(width: 44, height: 44)
                            .background(Fill.subtle, in: Circle())
                    }
                    Spacer()
                }
                .padding(.top, Space.md)

                Text(d.rawValue)
                    .pepText(.display)
                    .padding(.top, Space.lg)

                switch d {
                case .notifications:
                    card {
                        toggleRow("Replies to your questions", isOn: $pushReplies)
                        divider
                        toggleRow("Mentions", isOn: $pushMentions)
                        divider
                        toggleRow("Weekly digest", isOn: $pushWeekly)
                    }
                    .padding(.top, Space.lg)
                    hint("Push runs through the system prompt you approved during setup.")

                case .blocked:
                    if blocked.isEmpty {
                        emptyBlocked.padding(.top, Space.x4l)
                    } else {
                        card {
                            ForEach(Array(blocked.enumerated()), id: \.element.id) { i, user in
                                if i > 0 { divider }
                                HStack {
                                    Text("@\(user.handle)").pepText(.label)
                                    Spacer()
                                    Button("Unblock") {
                                        let id = user.id
                                        withAnimation(Motion.fast) { blocked.removeAll { $0.id == id } }
                                        Task { await BlockService.unblock(id) }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Ink.secondary)
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 52)
                            }
                        }
                        .padding(.top, Space.lg)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xl)
        }
        .scrollIndicators(.hidden)
    }

    @State private var blocked: [BlockedUser] = []

    private var emptyBlocked: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Ink.hint)
            Text("No blocked accounts").pepText(.label, Ink.tertiary)
            Text("Block someone from the ⋯ on their posts.")
                .pepText(.footnote, Ink.hint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: building blocks

    private func group(_ label: String, delay: Double,
                       @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            section(label)
            card(content)
                .padding(.top, Space.md)
        }
        .padding(.top, Space.x2l)
        .entrance(appeared, delay: delay, blur: false)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .background(Fill.subtle,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(height: 0.7)
            .padding(.leading, 18)
    }

    private func section(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Ink.tertiary)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .pepText(.footnote, Ink.tertiary)
            .padding(.top, Space.md)
            .padding(.horizontal, 4)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).pepText(.label)
            Spacer()
            Text(value).pepText(.label, Ink.secondary)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private func navRow(_ label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).pepText(.label, Ink.primary)
                Spacer()
                if let value {
                    Text(value).pepText(.caption, Ink.tertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pushRow(_ label: String, value: String, action: @escaping () -> Void) -> some View {
        navRow(label, value: value, action: action)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).pepText(.label)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Fill.charcoal)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private func linkRow(_ label: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(label).pepText(.label, Ink.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    SettingsView(onBack: {}).environment(AppModel())
}
