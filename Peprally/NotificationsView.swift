import SwiftUI

/// The activity rows, embedded as the profile's Notifications tab. Loads the
/// signed-in user's real notifications (written by DB triggers on reply and
/// follow); unread land under NEW, the rest under EARLIER. Opening the tab
/// marks them read.
struct ActivityList: View {
    // seeded synchronously with the fixtures: this list sits in the profile's
    // LazyVStack, and while it has no content it has no height, so a lazy
    // container can leave `.task` unfired and the tab permanently blank
    @State private var items: [ActivityItem] = SampleData.on ? SampleData.activity : []
    @State private var loaded = SampleData.on

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let unread = items.filter { !$0.read }
            let earlier = items.filter { $0.read }

            if items.isEmpty {
                if loaded { emptyState } else {
                    // keeps the row on-screen so the loader below actually runs
                    Color.clear.frame(height: 1)
                }
            } else {
                if !unread.isEmpty {
                    section("NEW").padding(.top, Space.md)
                    ForEach(Array(unread.enumerated()), id: \.element.id) { i, item in
                        row(item, unread: true, divider: i < unread.count - 1)
                    }
                }
                if !earlier.isEmpty {
                    section("EARLIER").padding(.top, unread.isEmpty ? Space.md : Space.lg)
                    ForEach(Array(earlier.enumerated()), id: \.element.id) { i, item in
                        row(item, unread: false, divider: i < earlier.count - 1)
                    }
                }
            }
        }
        .task {
            if !loaded {
                if SampleData.on {
                    items = SampleData.activity
                    loaded = true
                    return
                }
                items = await NotificationService.fetch()
                loaded = true
                await NotificationService.markAllRead()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No activity yet").pepText(.label, Ink.tertiary)
            Text("Replies, mentions and new followers show up here.")
                .pepText(.footnote, Ink.hint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.x4l)
    }

    private func section(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Ink.tertiary)
            .padding(.bottom, Space.xs)
    }

    @ViewBuilder
    private func row(_ item: ActivityItem, unread: Bool, divider: Bool) -> some View {
        switch item.kind {
        case .milestone(let text): milestoneCard(text, time: item.time, divider: divider)
        case .digest(let topic, let count): digestCard(topic, count: count, time: item.time, divider: divider)
        default: standardRow(item, unread: unread, divider: divider)
        }
    }

    // MARK: standard actor row (reply / mention / follow)

    private func standardRow(_ item: ActivityItem, unread: Bool, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(item)

            VStack(alignment: .leading, spacing: 5) {
                (Text(item.actor).fontWeight(.semibold) + Text(" \(action(item.kind))"))
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let preview = previewText(item.kind) {
                    Text(preview)
                        .pepText(.caption, Ink.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Fill.subtle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(item.time).pepText(.footnote, Ink.hint)
            }

            Spacer(minLength: 0)

            if unread {
                Circle().fill(Ink.primary).frame(width: 7, height: 7).padding(.top, 6)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if divider { hairline } }
    }

    // MARK: milestone card — a moment worth celebrating

    private func milestoneCard(_ text: String, time: String, divider: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Fill.charcoal)
                DotMeter(lit: 8, color: .white, dimOpacity: 0.4)
                    .frame(width: 18, height: 18)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Milestone · \(time)").pepText(.footnote, Ink.hint)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Fill.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { if divider { hairline } }
    }

    // MARK: digest card — what moved in a topic you follow

    private func digestCard(_ topic: String, count: Int, time: String, divider: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: FeedTopics.hex(for: topic)).opacity(0.7))
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Ink.primary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                (Text("\(count) new questions").fontWeight(.semibold)
                 + Text(" in \(topic) this week"))
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Weekly digest · \(time)").pepText(.footnote, Ink.hint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Fill.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { if divider { hairline } }
    }

    // MARK: pieces

    private func avatar(_ item: ActivityItem) -> some View {
        ZStack {
            Circle().fill(Color(hex: item.avatarHex))
            Text(item.initials)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private var hairline: some View {
        Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.7)
    }

    private func action(_ kind: ActivityItem.Kind) -> String {
        switch kind {
        case .reply:   "replied to your question"
        case .mention: "mentioned you"
        case .follow:  "started following you"
        default:       ""
        }
    }

    private func previewText(_ kind: ActivityItem.Kind) -> String? {
        switch kind {
        case .reply(let p), .mention(let p): p
        default: nil
        }
    }
}

#Preview {
    ScrollView { ActivityList().padding(.horizontal, 20) }
}
