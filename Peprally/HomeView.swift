import SwiftUI

/// A feed item. File-level so the composer can create them too.
struct FeedQuestion: Identifiable {
    let id: String
    var authorId: String = ""
    let topic: String
    let hex: UInt
    let time: String
    let title: String
    let preview: String
    let author: String
    let initials: String
    let avatarHex: UInt
    let badge: TrustBadge?
    var answers: Int
    var likes: Int = 0
    var isMine = false
    var attachment: FeedAttachment?
}

/// Media on a post: an image or a source link card.
enum FeedAttachment {
    case image
    case link(title: String, domain: String)
}

enum FeedTopics {
    // strictly monochrome — topic identity is carried by the label, not colour
    static let all: [(name: String, hex: UInt)] = [
        ("BPC-157", 0xE8E8E8), ("Semaglutide", 0xE8E8E8), ("TB-500", 0xE8E8E8), ("NAD+", 0xE8E8E8),
    ]
    static func hex(for topic: String) -> UInt {
        all.first(where: { $0.name == topic })?.hex ?? 0xE8E8E8
    }
}

/// Home — the one-page feed, X-weight: avatar rail left, light content
/// right, hairline rules between rows. The glass mark hub composes.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false
    @State private var topic: String?          // nil = All
    @State private var showProfile = false
    @State private var showSearch = false
    @State private var showCompose = false
    @State private var openQuestion: FeedQuestion?
    // moderation, local until the backend lands
    @State private var blockedIds: Set<String> = []
    @State private var showReported = false
    @State private var likedIds: Set<String> = []
    @State private var postError: String?

    // loaded from Supabase; empty until the first fetch (and while you have
    // no questions yet — the empty state covers that)
    @State private var feed: [FeedQuestion] = []
    @State private var feedLoaded = false

    private var visible: [FeedQuestion] {
        let unblocked = feed.filter { !blockedIds.contains($0.authorId) }
        return topic.map { t in unblocked.filter { $0.topic == t } } ?? unblocked
    }

    /// Pull the newest questions from Supabase.
    private func loadFeed() async {
        // dev hook: drive the whole app with sample content when the backend
        // is unavailable (SAMPLE_FEED=1) — for design / demo only
        if SampleData.on {
            feed = SampleData.feed
            feedLoaded = true
            return
        }
        if let items = try? await FeedService.fetch() {
            feed = items
            likedIds = await LikeService.myLikedQuestionIds()
            blockedIds = await BlockService.myBlockedIds()
        }
        feedLoaded = true
    }

    /// Tail of a thread: up to 3 other questions to keep reading — same
    /// topic first, then other recent ones so it never comes up empty.
    private func relatedQuestions(for q: FeedQuestion) -> [FeedQuestion] {
        let pool = feed.filter { $0.id != q.id && !blockedIds.contains($0.authorId) }
        let sameTopic = pool.filter { $0.topic == q.topic }
        let others = pool.filter { $0.topic != q.topic }
        return Array((sameTopic + others).prefix(3))
    }

    var body: some View {
        ZStack {
            // the feed stays mounted beneath an open thread — tearing it
            // down and rebuilding on back was a visible hitch, and it
            // also lost the scroll position. Opacity 0 while covered keeps
            // the state but stops the compositor drawing it every frame.
            // the feed stays solid until fully covered, then stops drawing —
            // no crossfade, the overlay just slides over it
            // instant switch: the overlay replaces the feed whole; the
            // feed keeps its state (and scroll) at zero opacity beneath
            feedFace
                .opacity(openQuestion == nil && !showProfile ? 1 : 0)

            if let q = openQuestion {
                ThreadView(question: q,
                           related: relatedQuestions(for: q),
                           onBack: { openQuestion = nil },
                           onReplied: {
                               if let i = feed.firstIndex(where: { $0.id == q.id }) {
                                   feed[i].answers += 1
                               }
                           },
                           onOpenRelated: { openQuestion = $0 })
                    .id(q.id)
            }

            if showProfile {
                ProfileView(onBack: { showProfile = false })
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    private var feedFace: some View {
        ZStack(alignment: .bottom) {
            // the feed runs full-bleed; the chrome is a glass slab it
            // slides beneath — the bar is the glass, not the controls
            ScrollView {
                LazyVStack(spacing: 0) {
                    if visible.isEmpty {
                        emptyState
                            .padding(.top, 130)
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { i, q in
                            rowButton(q, index: i)
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, 116)      // clears the chrome
                .padding(.bottom, 120)   // room for the hub
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: topic)
            }
            .scrollIndicators(.hidden)
            .refreshable { await loadFeed() }

            // top chrome over the feed
            VStack(spacing: Space.lg) {
                header
                    .padding(.horizontal, Space.xl)
                    .entrance(appeared, delay: 0, blur: false)

                topicRow
                    .entrance(appeared, delay: 0.1, blur: false)
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.md)
            .background {
                // the chrome slab
                // solid white with a soft gradient hand-off: blends
                // seamlessly with the page (the material's gray tint read
                // as a band against pure white) and removes the app's
                // last scroll-time blur
                Rectangle()
                    .fill(Color.white)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.white, .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 28)
                        .offset(y: 28)
                    }
                    .ignoresSafeArea(edges: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            hub
                .padding(.bottom, Space.lg)
                .entrance(appeared, delay: 0.4, blur: false)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .task {
            if !feedLoaded { await loadFeed() }
        }
        .onAppear {
            appeared = true
            // dev hooks: SHOW_PROFILE=1 / OPEN_THREAD=1 open the overlays
            if ProcessInfo.processInfo.environment["SHOW_PROFILE"] != nil {
                showProfile = true
            }
            if ProcessInfo.processInfo.environment["OPEN_THREAD"] != nil {
                openQuestion = feed.first
            }
            if ProcessInfo.processInfo.environment["SHOW_COMPOSE"] != nil {
                showCompose = true
            }
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeView { optimistic in
                // show it instantly, then persist and swap in the saved row
                withAnimation(Motion.fast) { feed.insert(optimistic, at: 0) }
                Task {
                    do {
                        let saved = try await FeedService.create(
                            title: optimistic.title, body: "", topicName: optimistic.topic)
                        if let i = feed.firstIndex(where: { $0.id == optimistic.id }) {
                            feed[i] = saved
                        }
                    } catch {
                        postError = error.localizedDescription
                        withAnimation(Motion.fast) { feed.removeAll { $0.id == optimistic.id } }
                    }
                }
            }
        }
        .alert("Reported", isPresented: $showReported) {
            Button("OK") {}
        } message: {
            Text("Thanks — the mods will review it.")
        }
        .alert("Couldn't post", isPresented: Binding(
            get: { postError != nil },
            set: { if !$0 { postError = nil } })) {
            Button("OK") {}
        } message: {
            Text(postError ?? "")
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(feed: feed,
                       onOpenQuestion: { q in
                           showSearch = false
                           openQuestion = q
                       })
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 14) {
            Text("Peprally")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.17)
                .foregroundStyle(Ink.primary)

            Spacer()

            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Ink.primary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Search")

            Button {
                showProfile = true
            } label: {
                ProfileAvatar(size: 32)
                    .overlay(alignment: .topTrailing) {
                        // unread activity lives on the profile now — the
                        // dot points you there
                        Circle().fill(Ink.primary)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: -1, y: -1)
                    }
            }
            .accessibilityLabel("Profile")
        }
        .frame(height: 44)
        .padding(.trailing, 4)
    }

    // MARK: topics

    private var topicRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                topicChip(nil, label: "All")
                ForEach(FeedTopics.all, id: \.name) { t in
                    topicChip(t.name, label: t.name)
                }
            }
            .padding(.horizontal, Space.xl)
            .frame(height: 36)
        }
        .frame(height: 36)
        .scrollIndicators(.hidden)
    }

    private func topicChip(_ value: String?, label: String) -> some View {
        let selected = topic == value
        return Button {
            withAnimation(Motion.select) { topic = value }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Ink.onDark : Ink.primary)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(selected ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.regular),
                            in: Capsule())
        }
    }

    private func rowButton(_ q: FeedQuestion, index i: Int) -> some View {
        row(q, divider: i < visible.count - 1)
        .contentShape(Rectangle())
        .onTapGesture { openQuestion = q }
        .cardEntrance(appeared, index: i)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
            removal: .opacity))
        .contextMenu {
            // moderators can act on any post
            if model.isModerator {
                Button {
                    // TODO: pin via the backend
                } label: {
                    Label("Pin to top", systemImage: "pin")
                }
                Button(role: .destructive) {
                    withAnimation(Motion.fast) { feed.removeAll { $0.id == q.id } }
                } label: {
                    Label("Remove post", systemImage: "trash")
                }
                Divider()
            }
            if q.isMine {
                Button(role: .destructive) {
                    withAnimation(Motion.fast) { feed.removeAll { $0.id == q.id } }
                    Task { try? await FeedService.delete(id: q.id) }
                } label: {
                    Label("Delete post", systemImage: "trash")
                }
            } else {
                Button {
                    // TODO: file the report with the backend
                    showReported = true
                } label: {
                    Label("Report post", systemImage: "flag")
                }
                Button(role: .destructive) {
                    withAnimation(Motion.fast) { _ = blockedIds.insert(q.authorId) }
                    Task { await BlockService.block(q.authorId) }
                } label: {
                    Label("Block \(q.author)", systemImage: "slash.circle")
                }
            }
        }
    }

    // MARK: empty state — the p, asleep

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("Quiet in here")
                .pepText(.lead)
            Text("No \(topic.map { "\($0) " } ?? "")questions yet — be the first to ask.")
                .pepText(.caption, Ink.tertiary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: feed rows — X-weight: avatar rail, light content, hairline rules

    private func row(_ q: FeedQuestion, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if q.isMine {
                ProfileAvatar(size: 36)
            } else {
                ZStack {
                    Circle().fill(Color(hex: q.avatarHex))
                    Text(q.initials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                }
                .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(q.author)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.13)
                        .foregroundStyle(Ink.primary)
                    if let badge = q.badge {
                        TrustBadgeView(badge: badge, compact: true)
                    }
                    Text("· \(q.time)").pepText(.footnote, Ink.hint)
                    Spacer(minLength: 0)
                }

                Text(q.title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !q.preview.isEmpty {
                    Text(q.preview)
                        .pepText(.caption, Ink.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let attachment = q.attachment {
                    attachmentView(attachment)
                        .padding(.top, 6)
                }

                // the action row: answers · like · share
                HStack(spacing: 28) {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(q.answers)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Ink.tertiary)

                    Button {
                        let liked = likedIds.contains(q.id)
                        withAnimation(Motion.select) {
                            if liked {
                                likedIds.remove(q.id)
                                if let i = feed.firstIndex(where: { $0.id == q.id }) {
                                    feed[i].likes = max(0, feed[i].likes - 1)
                                }
                            } else {
                                likedIds.insert(q.id)
                                if let i = feed.firstIndex(where: { $0.id == q.id }) {
                                    feed[i].likes += 1
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        Task { await LikeService.setQuestion(q.id, liked: !liked) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: likedIds.contains(q.id) ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .medium))
                                .symbolEffect(.bounce, value: likedIds.contains(q.id))
                                .scaleEffect(likedIds.contains(q.id) ? 1.12 : 1)
                                .animation(.spring(response: 0.28, dampingFraction: 0.5),
                                           value: likedIds.contains(q.id))
                            Text("\(q.likes)")
                                .font(.system(size: 12, weight: .medium))
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(likedIds.contains(q.id) ? Ink.primary : Ink.tertiary)
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: "\(q.title) — on Peprally") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Ink.tertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.7)
            }
        }
    }

    // MARK: attachments

    @ViewBuilder
    private func attachmentView(_ attachment: FeedAttachment) -> some View {
        switch attachment {
        case .image:
            // placeholder media until real uploads exist — a grey ramp (never
            // a hue) with a media glyph so it still reads as "image here"
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [Fill.subtle, Fill.regular],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 180)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Ink.hint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        case .link(let title, let domain):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Fill.regular)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.13)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(2)
                    Text(domain).pepText(.footnote, Ink.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: the ask pill — the app's own capsule species, floating

    private var hub: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showCompose = true
        } label: {
            HStack(spacing: 10) {
                // the mark itself, resting — the dots are the character
                MarkView(color: .white, animated: false)
                    .frame(width: 18, height: 18)
                Text("Ask")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(Ink.onDark)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(Fill.charcoal, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
        .buttonStyle(AskPillStyle())
    }

}

/// The signed-in user's avatar: initials from their handle. The demo build
/// shows the bundled demo photo instead.
struct ProfileAvatar: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            #if DEMO
            Image("avatar-jake")
                .resizable()
                .scaledToFill()
                .grayscale(1.0)   // keep photo avatars inside the monochrome system
            #else
            Circle().fill(Color(hex: DisplayFormat.avatarHex(from: model.handle)))
            Text(DisplayFormat.initials(from: model.handle))
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Ink.secondary)
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Feed rows squeeze slightly under the finger — content, not chrome.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.select, value: configuration.isPressed)
    }
}

/// The ask pill's press: a decisive squeeze, slightly deeper than the
/// standard capsule since it floats.
struct AskPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.select, value: configuration.isPressed)
    }
}

#Preview {
    HomeView().environment(AppModel())
}
