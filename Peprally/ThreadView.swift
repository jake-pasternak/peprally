import SwiftUI

struct ReplyItem: Identifiable {
    let id: String
    var authorId: String = ""
    let author: String
    let initials: String
    let avatarHex: UInt
    let badge: TrustBadge?
    let time: String
    let text: String
    var isMine = false
    var vouches: Int = 0
}

/// The thread: a question opened from the feed, its replies underneath,
/// and a reply bar pinned above the keyboard. Same open-rows-on-rules
/// language as the feed.
struct ThreadView: View {
    @Environment(AppModel.self) private var model
    let question: FeedQuestion
    var related: [FeedQuestion] = []
    var onBack: () -> Void = {}
    var onReplied: () -> Void = {}
    var onOpenRelated: (FeedQuestion) -> Void = { _ in }

    @State private var appeared = false
    @State private var replies: [ReplyItem] = []
    @State private var repliesLoaded = false
    @State private var replyText = ""
    @State private var showReported = false
    @State private var likedIds: Set<String> = []
    @FocusState private var focused: Bool

    /// Load this question's replies from Supabase.
    private func loadReplies() async {
        if SampleData.on {
            replies = SampleData.replies(for: question.id)
            repliesLoaded = true
            return
        }
        if let items = try? await ReplyService.fetch(questionId: question.id) {
            replies = items
            likedIds = await LikeService.myLikedReplyIds(in: items.map { $0.id })
        }
        repliesLoaded = true
    }

    var body: some View {
        VStack(spacing: 0) {
            // chrome
            ZStack {
                Text("Thread")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(Ink.primary)
                PepBackChip(action: onBack)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    questionBlock
                        .entrance(appeared, delay: 0, blur: false)

                    Rectangle().fill(Color.black.opacity(0.07)).frame(height: 0.7)

                    ForEach(Array(replies.enumerated()), id: \.element.id) { i, r in
                        replyRow(r, divider: i < replies.count - 1)
                            .entrance(appeared, delay: 0.12 + 0.06 * Double(min(i, 5)), blur: false)
                            .contextMenu {
                                if !r.isMine {
                                    Button {
                                        // TODO: file the report with the backend
                                        showReported = true
                                    } label: {
                                        Label("Report reply", systemImage: "flag")
                                    }
                                    Button(role: .destructive) {
                                        let blockedId = r.authorId
                                        withAnimation(Motion.fast) {
                                            replies.removeAll { $0.authorId == blockedId }
                                        }
                                        Task { await BlockService.block(blockedId) }
                                    } label: {
                                        Label("Block \(r.author)", systemImage: "slash.circle")
                                    }
                                }
                            }
                    }

                    if !related.isEmpty {
                        relatedSection
                            .entrance(appeared, delay: 0.12 + 0.06 * Double(min(replies.count, 5)), blur: false)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.x2l)
            }
            .scrollIndicators(.hidden)

            replyBar
        }
        .background(Color.white)
        .tint(Ink.secondary)
        .alert("Reported", isPresented: $showReported) {
            Button("OK") {}
        } message: {
            Text("Thanks — the mods will review it.")
        }
        .onAppear { appeared = true }
        .task {
            if !repliesLoaded { await loadReplies() }
        }
    }

    // MARK: the question, in full

    private var questionBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if question.isMine {
                    ProfileAvatar(size: 40)
                } else {
                    ZStack {
                        Circle().fill(Color(hex: question.avatarHex))
                        Text(question.initials)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Ink.secondary)
                    }
                    .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(question.author)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.14)
                            .foregroundStyle(Ink.primary)
                        if let badge = question.badge {
                            TrustBadgeView(badge: badge, compact: true)
                        }
                    }
                    Text(question.time).pepText(.footnote, Ink.hint)
                }
                Spacer()
            }
            .padding(.top, Space.lg)

            Text(question.title)
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.57)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)

            if !question.preview.isEmpty {
                Text(question.preview)
                    .pepText(.body, Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm)
            }

            HStack {
                Text(question.topic)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Fill.regular, in: Capsule())

                Spacer()

                Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")").pepText(.footnote, Ink.tertiary)
            }
            .padding(.top, Space.md)
            .padding(.bottom, Space.lg)
        }
    }

    // MARK: replies

    private func replyRow(_ r: ReplyItem, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if r.isMine {
                ProfileAvatar(size: 32)
            } else {
                ZStack {
                    Circle().fill(Color(hex: r.avatarHex))
                    Text(r.initials)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                }
                .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.author)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.13)
                        .foregroundStyle(Ink.primary)
                    if let badge = r.badge {
                        TrustBadgeView(badge: badge, compact: true)
                    }
                    Text("· \(r.time)").pepText(.footnote, Ink.hint)
                    Spacer(minLength: 0)
                }

                Text(r.text)
                    .pepText(.label, Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !r.isMine {
                    Button {
                        let liked = likedIds.contains(r.id)
                        withAnimation(Motion.select) {
                            if liked {
                                likedIds.remove(r.id)
                                if let i = replies.firstIndex(where: { $0.id == r.id }) {
                                    replies[i].vouches = max(0, replies[i].vouches - 1)
                                }
                            } else {
                                likedIds.insert(r.id)
                                if let i = replies.firstIndex(where: { $0.id == r.id }) {
                                    replies[i].vouches += 1
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        Task { await LikeService.setReply(r.id, liked: !liked) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: likedIds.contains(r.id) ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .medium))
                            Text("\(r.vouches)")
                                .font(.system(size: 12, weight: .medium))
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(likedIds.contains(r.id) ? Ink.primary : Ink.tertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle()
                    .fill(Color.black.opacity(0.07))
                    .frame(height: 0.7)
            }
        }
    }

    // MARK: more in topic — fills the tail of a short thread and turns
    // the dead end into discovery. Same-topic questions first, then other
    // recent ones so it always has something to show.

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MORE IN \(question.topic.uppercased())")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(Ink.tertiary)
                .padding(.top, Space.x2l)
                .padding(.bottom, Space.xs)

            ForEach(Array(related.enumerated()), id: \.element.id) { i, q in
                Button { onOpenRelated(q) } label: {
                    relatedRow(q, divider: i < related.count - 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relatedRow(_ q: FeedQuestion, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(q.title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(q.topic)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Fill.regular, in: Capsule())
                    Text("\(q.answers) \(q.answers == 1 ? "reply" : "replies")").pepText(.footnote, Ink.tertiary)
                    Text("· \(q.time)").pepText(.footnote, Ink.hint)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.hint)
                .padding(.top, 3)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle().fill(Color.black.opacity(0.07)).frame(height: 0.7)
            }
        }
    }

    // MARK: reply bar

    private var replyBar: some View {
        HStack(spacing: 10) {
            ProfileAvatar(size: 28)

            TextField("", text: $replyText,
                      prompt: Text("Add a reply…").foregroundStyle(Ink.hint))
                .font(.system(size: 14, weight: .medium))
                .focused($focused)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Fill.regular, in: Capsule())

            Button {
                let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let name = model.handle.isEmpty ? "you" : model.handle
                let tempId = "temp-\(UUID().uuidString)"
                // optimistic — show it, then persist and swap in the saved row
                withAnimation(Motion.select) {
                    replies.append(ReplyItem(
                        id: tempId, author: name,
                        initials: DisplayFormat.initials(from: name),
                        avatarHex: DisplayFormat.avatarHex(from: name),
                        badge: nil, time: "now", text: trimmed, isMine: true))
                    replyText = ""
                }
                onReplied()
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                Task {
                    do {
                        let saved = try await ReplyService.create(questionId: question.id, body: trimmed)
                        if let i = replies.firstIndex(where: { $0.id == tempId }) { replies[i] = saved }
                    } catch {
                        withAnimation(Motion.fast) { replies.removeAll { $0.id == tempId } }
                    }
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.onDark)
                    .frame(width: 32, height: 32)
                    .background(Fill.charcoal, in: Circle())
            }
            .opacity(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.sm)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.07)).frame(height: 0.7)
        }
    }
}

#Preview {
    ThreadView(question: FeedQuestion(
        id: "1", topic: "BPC-157", hex: 0xE9E9E9, time: "2h",
        title: "Does BPC-157 actually help tendon healing?",
        preview: "The evidence is promising but mostly preclinical.",
        author: "Dr. Sarah Chen", initials: "SC", avatarHex: 0xDFDFDF,
        badge: .verified(credential: "Physician"), answers: 12))
        .environment(AppModel())
}
