import SwiftUI

/// Your profile, modeled on X's anatomy: identity header, stat line, a
/// tab bar (Questions / Replies / Notifications), and a feed of your activity
/// below in the home feed's row language. Overlays the feed like a
/// thread does. Everything works: verification routes into the verify
/// flow, sign out signs out.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    /// notifications are private — the tab only exists on YOUR profile;
    /// visiting someone else's profile never shows it
    var isOwnProfile = true

    @State private var appeared = false
    @State private var tab: Tab = .questions
    @State private var showSettings = false
    @State private var showEdit = false
    @State private var showTopics = false
    @State private var openQuestion: FeedQuestion?
    @State private var myQuestions: [FeedQuestion] = []
    @State private var myReplies: [MyReply] = []
    @State private var profileLoaded = false
    @Namespace private var underline

    enum Tab: String, CaseIterable {
        case questions = "Questions"
        case replies = "Replies"
        case activity = "Notifications"
    }

    private var tabs: [Tab] {
        isOwnProfile ? Tab.allCases : [.questions, .replies]
    }

    private var handle: String {
        model.handle.isEmpty ? "jake" : model.handle
    }
    private var topics: [String] {
        model.followedPeptides.isEmpty
            ? FeedTopics.all.map(\.name)
            : model.followedPeptides.sorted()
    }

    var body: some View {
        ZStack {
            // instant switch — state kept, draw skipped while covered
            profileFace
                .opacity(showSettings || openQuestion != nil ? 0 : 1)

            if showSettings {
                SettingsView(onBack: { showSettings = false })
            }

            if let q = openQuestion {
                ThreadView(question: q,
                           onBack: { openQuestion = nil })
            }
        }
        .sheet(isPresented: $showEdit) {
            EditProfileSheet()
        }
        .sheet(isPresented: $showTopics) {
            TopicManager()
        }
    }

    private var profileFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            // nav row: back chip left, settings right
            HStack {
                PepBackChip(action: onBack)
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                        .frame(width: 44, height: 44)
                        .background(Fill.subtle, in: Circle())
                }
            }
            .padding(.top, Space.md)
            .padding(.horizontal, Space.xl)

            // identity: avatar left, the actions right — grouped tight
            HStack(alignment: .center) {
                ProfileAvatar(size: 72)
                Spacer()
                HStack(spacing: 8) {
                    Button("Edit") { showEdit = true }
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(-0.12)
                        .foregroundStyle(Ink.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Fill.regular, in: Capsule())
                    // verification is a Settings-only concern; the profile
                    // shows status (the pending chip here, the seal by the
                    // handle once approved) but never the entry point
                    if model.verificationPending {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .medium))
                            Text("In review")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Fill.subtle, in: Capsule())
                    }
                }
            }
            .padding(.top, Space.lg)
            .padding(.horizontal, Space.xl)
            .entrance(appeared, delay: 0, blur: false)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(handle)")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(Ink.primary)
                    if model.isProfessional && !model.verificationPending {
                        TrustBadgeView(badge: .verified(credential: "Physician"), compact: true)
                    }
                    if model.isModerator {
                        TrustBadgeView(badge: .moderator)
                    }
                }

                // every stat acts: counts jump to their tab, topics open
                // the followed-topics sheet
                HStack(spacing: 14) {
                    Button { withAnimation(Motion.select) { tab = .questions } } label: {
                        stat("\(myQuestions.count)", "questions")
                    }
                    Button { withAnimation(Motion.select) { tab = .replies } } label: {
                        stat("\(myReplies.count)", "answers")
                    }
                    Button { showTopics = true } label: {
                        stat("\(topics.count)", "topics")
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, Space.md)
            }
            .padding(.top, Space.md)
            .padding(.horizontal, Space.xl)
            .entrance(appeared, delay: 0.08, blur: false)

            // tab bar — X's underline, in rally green
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { t in
                    Button {
                        withAnimation(Motion.select) { tab = t }
                    } label: {
                        VStack(spacing: 10) {
                            HStack(spacing: 5) {
                                Text(t.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .tracking(-0.13)
                                    .foregroundStyle(tab == t ? Ink.primary : Ink.tertiary)
                                if t == .activity && tab != .activity {
                                    // unread, mocked on until push lands
                                    Circle().fill(Ink.primary).frame(width: 6, height: 6)
                                }
                            }
                            ZStack {
                                Color.clear.frame(height: 2.5)
                                if tab == t {
                                    Capsule()
                                        .fill(Fill.charcoal)
                                        .frame(width: 44, height: 2.5)
                                        .matchedGeometryEffect(id: "underline", in: underline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.top, Space.x2l)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.7)
            }
            .entrance(appeared, delay: 0.16, blur: false)

            // the activity feed, in the home feed's row language
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch tab {
                    case .questions:
                        if myQuestions.isEmpty {
                            emptyTab(profileLoaded ? "No questions yet" : " ")
                        } else {
                            ForEach(myQuestions) { q in
                                Button { openQuestion = q } label: {
                                    questionRow(q.title, time: q.time, answers: q.answers,
                                                divider: q.id != myQuestions.last?.id)
                                }
                                .buttonStyle(CardPressStyle())
                            }
                        }
                    case .replies:
                        if myReplies.isEmpty {
                            emptyTab(profileLoaded ? "No replies yet" : " ")
                        } else {
                            ForEach(myReplies) { r in
                                Button {
                                    if let parent = r.parent { openQuestion = parent }
                                } label: {
                                    replyRow((to: r.to, text: r.text, time: r.time),
                                             divider: r.id != myReplies.last?.id)
                                }
                                .buttonStyle(CardPressStyle())
                            }
                        }
                    case .activity:
                        ActivityList()
                    }
                }
                .padding(.horizontal, Space.xl)
                .animation(Motion.fast, value: tab)
            }
            .scrollIndicators(.hidden)
            .entrance(appeared, delay: 0.22, blur: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            appeared = true
            // dev hook: SHOW_SETTINGS=1 opens the settings overlay
            if ProcessInfo.processInfo.environment["SHOW_SETTINGS"] != nil {
                showSettings = true
            }
            if ProcessInfo.processInfo.environment["SHOW_ACTIVITY"] != nil {
                tab = .activity
            }
        }
        .task {
            if !profileLoaded {
                if SampleData.on {
                    myQuestions = SampleData.myQuestions
                    myReplies = SampleData.myReplies
                    profileLoaded = true
                    return
                }
                myQuestions = (try? await ProfileService.myQuestions()) ?? []
                myReplies = (try? await ProfileService.myReplies()) ?? []
                profileLoaded = true
            }
        }
    }

    private func emptyTab(_ text: String) -> some View {
        Text(text)
            .pepText(.caption, Ink.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.x4l)
    }

    // MARK: pieces

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.14)
                .foregroundStyle(Ink.primary)
            Text(label).pepText(.caption, Ink.tertiary)
        }
    }

    private func questionRow(_ title: String, time: String, answers: Int,
                             divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.15)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(answers) answers · \(time)")
                .pepText(.footnote, Ink.hint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.7)
            }
        }
    }

    private func replyRow(_ r: (to: String, text: String, time: String),
                          divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Replying to \(Text(r.to).foregroundStyle(Ink.secondary))")
                .pepText(.footnote, Ink.tertiary)
                .lineLimit(1)
            Text(r.text)
                .pepText(.body, Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(r.time).pepText(.footnote, Ink.hint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.7)
            }
        }
    }

}

/// Add and remove the topics you follow — tap to toggle. Writes straight
/// to the model's followedPeptides.
private struct TopicManager: View {
    @Environment(AppModel.self) private var model

    /// the full starter catalog, same as onboarding
    private static let all: [String] = [
        "BPC-157", "TB-500", "GHK-Cu", "Thymosin α-1",
        "Semaglutide", "Tirzepatide", "Retatrutide", "MOTS-c",
        "CJC-1295", "Ipamorelin", "NAD+", "Epithalon",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Topics you follow")
                .pepText(.title)
                .padding(.top, Space.x2l)
            Text("Tap to add or remove — this shapes your feed")
                .pepText(.footnote, Ink.tertiary)
                .padding(.top, 4)

            ScrollView {
                FlexWrap(spacing: 8) {
                    ForEach(Self.all, id: \.self) { name in
                        let on = model.followedPeptides.contains(name)
                        Button {
                            withAnimation(Motion.select) {
                                if on { model.followedPeptides.remove(name) }
                                else { model.followedPeptides.insert(name) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: on ? "checkmark" : "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(name).font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(on ? Ink.onDark : Ink.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(on ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.regular),
                                        in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

/// Edit name and handle — writes straight to the model until the
/// backend owns the profile.
private struct EditProfileSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit profile")
                .pepText(.title)
                .padding(.top, Space.x2l)

            field("USERNAME", text: $handle, prompt: "username")
                .padding(.top, Space.x2l)

            Spacer()

            Button("Save") {
                model.handle = handle.trimmingCharacters(in: .whitespaces)
                    .lowercased().replacingOccurrences(of: "@", with: "")
                dismiss()
            }
            .buttonStyle(.pepPrimary)
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.xl)
        .presentationDetents([.height(360)])
        .presentationCornerRadius(24)
        .onAppear {
            handle = model.handle.isEmpty ? "jake" : model.handle
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(Ink.tertiary)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Ink.hint))
                .font(.system(size: 16, weight: .medium))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 18)
                .frame(height: Metrics.input)
                .background(Fill.regular,
                            in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        }
    }
}

#Preview {
    ProfileView(onBack: {}).environment(AppModel())
}
