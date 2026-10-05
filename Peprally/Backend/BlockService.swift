import Foundation
import Supabase

struct BlockedUser: Identifiable {
    let id: String       // the blocked user's id
    let handle: String
}

/// The user's block list. Blocked users' content is filtered from the feed
/// client-side (see HomeView) using these ids.
enum BlockService {
    static func myBlocked() async -> [BlockedUser] {
        guard let uid = currentUserId else { return [] }
        struct Row: Decodable { let blocked_id: UUID; let blocked: AuthorRow? }
        let rows: [Row] = (try? await supabase
            .from("blocks")
            .select("blocked_id,blocked:profiles!blocked_id(handle,avatar_url,is_professional,verification_status,credential,is_moderator)")
            .eq("blocker_id", value: uid.uuidString)
            .execute().value) ?? []
        return rows.map { BlockedUser(id: $0.blocked_id.uuidString, handle: $0.blocked?.displayHandle ?? "member") }
    }

    static func myBlockedIds() async -> Set<String> {
        Set(await myBlocked().map { $0.id })
    }

    static func block(_ userId: String) async {
        guard let uid = currentUserId, userId != uid.uuidString else { return }
        struct Row: Encodable { let blocker_id: String; let blocked_id: String }
        _ = try? await supabase.from("blocks")
            .upsert(Row(blocker_id: uid.uuidString, blocked_id: userId)).execute()
    }

    static func unblock(_ userId: String) async {
        guard let uid = currentUserId else { return }
        _ = try? await supabase.from("blocks").delete()
            .eq("blocker_id", value: uid.uuidString)
            .eq("blocked_id", value: userId).execute()
    }
}
