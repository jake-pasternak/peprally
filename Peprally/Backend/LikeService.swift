import Foundation
import Supabase

/// Likes on questions and replies. The `*_count` columns are kept in sync by
/// DB triggers, so the client only inserts/deletes the user's own like row.
enum LikeService {
    // MARK: questions

    /// Which of the current user's questions are liked (for the filled heart).
    static func myLikedQuestionIds() async -> Set<String> {
        guard let uid = currentUserId else { return [] }
        struct Row: Decodable { let question_id: UUID }
        let rows: [Row] = (try? await supabase
            .from("question_likes").select("question_id")
            .eq("user_id", value: uid.uuidString)
            .execute().value) ?? []
        return Set(rows.map { $0.question_id.uuidString })
    }

    static func setQuestion(_ id: String, liked: Bool) async {
        guard let uid = currentUserId, !id.hasPrefix("temp-") else { return }
        if liked {
            struct Row: Encodable { let user_id: String; let question_id: String }
            _ = try? await supabase.from("question_likes")
                .upsert(Row(user_id: uid.uuidString, question_id: id)).execute()
        } else {
            _ = try? await supabase.from("question_likes").delete()
                .eq("user_id", value: uid.uuidString)
                .eq("question_id", value: id).execute()
        }
    }

    // MARK: replies

    static func myLikedReplyIds(in replyIds: [String]) async -> Set<String> {
        guard let uid = currentUserId, !replyIds.isEmpty else { return [] }
        struct Row: Decodable { let reply_id: UUID }
        let rows: [Row] = (try? await supabase
            .from("reply_likes").select("reply_id")
            .eq("user_id", value: uid.uuidString)
            .in("reply_id", values: replyIds)
            .execute().value) ?? []
        return Set(rows.map { $0.reply_id.uuidString })
    }

    static func setReply(_ id: String, liked: Bool) async {
        guard let uid = currentUserId, !id.hasPrefix("temp-") else { return }
        if liked {
            struct Row: Encodable { let user_id: String; let reply_id: String }
            _ = try? await supabase.from("reply_likes")
                .upsert(Row(user_id: uid.uuidString, reply_id: id)).execute()
        } else {
            _ = try? await supabase.from("reply_likes").delete()
                .eq("user_id", value: uid.uuidString)
                .eq("reply_id", value: id).execute()
        }
    }
}
