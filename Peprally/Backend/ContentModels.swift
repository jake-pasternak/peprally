import Foundation

/// Formatting helpers that turn raw profile/timestamp data into the display
/// bits the feed and thread views expect (initials, avatar tint, "2h" ago).
enum DisplayFormat {
    static func initials(from handle: String) -> String {
        let h = handle.replacingOccurrences(of: "@", with: "")
        return h.isEmpty ? "•" : String(h.prefix(2)).uppercased()
    }

    /// Deterministic avatar shade from a stable seed (the handle). Strictly
    /// monochrome — an equal-channel grey ramp kept in the light band so the
    /// `Ink.secondary` initials stay legible; lightness varies per user, no hue.
    static func avatarHex(from seed: String) -> UInt {
        let palette: [UInt] = [0xF2F2F2, 0xECECEC, 0xE6E6E6, 0xE0E0E0,
                               0xEAEAEA, 0xDCDCDC, 0xE4E4E4, 0xEFEFEF]
        var hash = 5381
        for byte in seed.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return palette[Int(hash.magnitude % UInt(palette.count))]
    }

    static func relative(_ iso: String) -> String {
        guard let date = parseTimestamp(iso) else { return "now" }
        let s = Date().timeIntervalSince(date)
        switch s {
        case ..<60:      return "now"
        case ..<3600:    return "\(Int(s / 60))m"
        case ..<86400:   return "\(Int(s / 3600))h"
        case ..<604800:  return "\(Int(s / 86400))d"
        default:         return "\(Int(s / 604800))w"
        }
    }

    /// Postgres timestamptz → Date, tolerant of micro-second fractions
    /// (ISO8601DateFormatter only accepts milliseconds).
    private static func parseTimestamp(_ input: String) -> Date? {
        var str = input
        if let dot = str.firstIndex(of: ".") {
            let start = str.index(after: dot)
            var end = start
            while end < str.endIndex, str[end].isNumber { end = str.index(after: end) }
            if str.distance(from: start, to: end) > 3 {
                let millis = str[start..<end].prefix(3)
                str.replaceSubrange(start..<end, with: millis)
            }
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}

/// Embedded author profile on a question/reply row.
struct AuthorRow: Decodable {
    let handle: String?
    let avatar_url: String?
    let is_professional: Bool
    let verification_status: String
    let credential: String?
    let is_moderator: Bool

    var badge: TrustBadge? {
        verification_status == "verified" ? .verified(credential: credential ?? "Verified") : nil
    }
    var displayHandle: String { handle ?? "member" }
}

/// A `questions` row with author + topic embedded (see FeedService.columns).
struct QuestionRow: Decodable {
    let id: UUID
    let author_id: UUID
    let title: String
    let body: String
    let like_count: Int
    let reply_count: Int
    let created_at: String
    let author: AuthorRow?
    let topic: TopicEmbed?

    struct TopicEmbed: Decodable { let name: String; let hex: String }

    func toFeed(currentUserId: UUID?) -> FeedQuestion {
        let handle = author?.displayHandle ?? "member"
        return FeedQuestion(
            id: id.uuidString,
            authorId: author_id.uuidString,
            topic: topic?.name ?? "General",
            hex: UInt(topic?.hex ?? "E8E8E6", radix: 16) ?? 0xE8E8E8,
            time: DisplayFormat.relative(created_at),
            title: title,
            preview: body,
            author: handle,
            initials: DisplayFormat.initials(from: handle),
            avatarHex: DisplayFormat.avatarHex(from: handle),
            badge: author?.badge,
            answers: reply_count,
            likes: like_count,
            isMine: author_id == currentUserId
        )
    }
}

/// A `replies` row with the author embedded.
struct ReplyRow: Decodable {
    let id: UUID
    let author_id: UUID
    let body: String
    let like_count: Int
    let created_at: String
    let author: AuthorRow?

    func toReplyItem(currentUserId: UUID?) -> ReplyItem {
        let handle = author?.displayHandle ?? "member"
        return ReplyItem(
            id: id.uuidString,
            authorId: author_id.uuidString,
            author: handle,
            initials: DisplayFormat.initials(from: handle),
            avatarHex: DisplayFormat.avatarHex(from: handle),
            badge: author?.badge,
            time: DisplayFormat.relative(created_at),
            text: body,
            isMine: author_id == currentUserId,
            vouches: like_count
        )
    }
}
