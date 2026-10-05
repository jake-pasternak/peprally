import SwiftUI

/// Search — the missing surface that lets you reach people, topics, and
/// questions beyond your own feed. People and topics are mock until the
/// backend lands; question search filters the live feed.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    let feed: [FeedQuestion]
    var onOpenQuestion: (FeedQuestion) -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    /// The same cast that writes the feed and the threads — searching for
    /// someone you just read has to find them.
    private typealias Person = SampleData.Person
    private static let people: [Person] = SampleData.people

    private var q: String { query.trimmingCharacters(in: .whitespaces).lowercased() }
    private var peopleHits: [Person] {
        guard !q.isEmpty else { return [] }
        return Self.people.filter { $0.id.contains(q) || $0.name.lowercased().contains(q) }
    }
    private var topicHits: [String] { q.isEmpty ? FeedTopics.all.map(\.name) : FeedTopics.all.map(\.name).filter { $0.lowercased().contains(q) } }
    private var questionHits: [FeedQuestion] { q.isEmpty ? [] : feed.filter { $0.title.lowercased().contains(q) } }

    var body: some View {
        VStack(spacing: 0) {
            // search bar
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(Ink.tertiary)
                    TextField("", text: $query,
                              prompt: Text("Search people, topics, questions").foregroundStyle(Ink.hint))
                        .font(.system(size: 15, weight: .medium))
                        .autocorrectionDisabled()
                        .focused($focused)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Ink.hint)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Fill.regular, in: Capsule())

                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.md)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !topicHits.isEmpty {
                        section("TOPICS")
                        FlowChips(items: topicHits)
                            .padding(.top, Space.sm)
                            .padding(.bottom, Space.lg)
                    }

                    if !peopleHits.isEmpty {
                        section("PEOPLE")
                        ForEach(Array(peopleHits.enumerated()), id: \.offset) { _, p in
                            personRow(p)
                        }
                        .padding(.bottom, Space.lg)
                    }

                    if !questionHits.isEmpty {
                        section("QUESTIONS")
                        ForEach(questionHits) { item in
                            Button { onOpenQuestion(item) } label: { questionRow(item) }
                                .buttonStyle(.plain)
                        }
                    }

                    if !q.isEmpty && peopleHits.isEmpty && topicHits.isEmpty && questionHits.isEmpty {
                        Text("No results for “\(query)”")
                            .pepText(.label, Ink.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Space.x4l)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.white.ignoresSafeArea())
        .tint(Ink.secondary)
        .onAppear {
            Task { try? await Task.sleep(for: .seconds(0.35)); focused = true }
        }
    }

    private func section(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Ink.tertiary)
            .padding(.top, Space.sm)
    }

    private func personRow(_ p: Person) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: p.hex))
                Text(p.initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(width: 40, height: 40)
            HStack(spacing: 6) {
                Text("@\(p.id)").pepText(.label, Ink.primary)
                if let b = p.badge, b != .moderator { TrustBadgeView(badge: b, compact: true) }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func questionRow(_ item: FeedQuestion) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.15)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(item.author) · \(item.answers) answers").pepText(.footnote, Ink.hint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.7)
        }
    }
}

/// Simple wrapping topic chips.
private struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlexWrap(spacing: 8) {
            ForEach(items, id: \.self) { name in
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Fill.regular, in: Capsule())
            }
        }
    }
}

/// Minimal flow layout for wrapping chips.
struct FlexWrap: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pts = arrange(proposal, subviews).points
        for (v, p) in zip(subviews, pts) {
            v.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func arrange(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var pts: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y)); x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return (CGSize(width: maxW, height: y + rowH), pts)
    }
}

#Preview {
    SearchView(feed: [], onOpenQuestion: { _ in })
}
