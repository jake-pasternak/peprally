import Foundation
import Supabase

/// One row in the activity feed, mapped from a `notifications` row.
struct ActivityItem: Identifiable {
    enum Kind {
        case reply(preview: String)
        case mention(preview: String)
        case follow
        case milestone(String)
        case digest(topic: String, count: Int)
    }
    let id: String
    let initials: String
    let avatarHex: UInt
    let actor: String
    let time: String
    let kind: Kind
    let read: Bool
}

/// Reads the signed-in user's notifications (written by DB triggers on reply
/// and follow). Mentions/milestones/digests will light up as their sources
/// come online; unknown types are skipped.
enum NotificationService {
    static func fetch() async -> [ActivityItem] {
        guard let uid = currentUserId else { return [] }
        struct Row: Decodable {
            let id: UUID
            let type: String
            let body: String?
            let read_at: String?
            let created_at: String
            let actor: AuthorRow?
        }
        let rows: [Row] = (try? await supabase
            .from("notifications")
            .select("id,type,body,read_at,created_at,actor:profiles!actor_id(handle,avatar_url,is_professional,verification_status,credential,is_moderator)")
            .eq("user_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .limit(50)
            .execute().value) ?? []

        return rows.compactMap { row in
            let handle = row.actor?.displayHandle ?? "someone"
            let kind: ActivityItem.Kind
            switch row.type {
            case "reply":     kind = .reply(preview: row.body ?? "")
            case "mention":   kind = .mention(preview: row.body ?? "")
            case "follow":    kind = .follow
            case "milestone": kind = .milestone(row.body ?? "")
            default:          return nil   // digest etc. not surfaced yet
            }
            return ActivityItem(
                id: row.id.uuidString,
                initials: DisplayFormat.initials(from: handle),
                avatarHex: DisplayFormat.avatarHex(from: handle),
                actor: handle,
                time: DisplayFormat.relative(row.created_at),
                kind: kind,
                read: row.read_at != nil)
        }
    }

    /// Mark all of the user's unread notifications read (call when the tab opens).
    static func markAllRead() async {
        guard let uid = currentUserId else { return }
        struct Patch: Encodable { let read_at: String }
        _ = try? await supabase
            .from("notifications")
            .update(Patch(read_at: ISO8601DateFormatter().string(from: Date())))
            .eq("user_id", value: uid.uuidString)
            .is("read_at", value: nil)
            .execute()
    }
}
