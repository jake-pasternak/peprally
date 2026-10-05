import Foundation
import Supabase

/// Reads and writes replies within a thread.
enum ReplyService {
    static let columns = """
    id,author_id,body,like_count,created_at,\
    author:profiles!author_id(handle,avatar_url,is_professional,verification_status,credential,is_moderator)
    """

    static func fetch(questionId: String) async throws -> [ReplyItem] {
        let uid = currentUserId
        let rows: [ReplyRow] = try await supabase
            .from("replies")
            .select(columns)
            .eq("question_id", value: questionId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.toReplyItem(currentUserId: uid) }
    }

    static func create(questionId: String, body: String) async throws -> ReplyItem {
        guard let uid = currentUserId else { throw BackendError.notAuthenticated }
        struct NewReply: Encodable {
            let question_id: String
            let author_id: String
            let body: String
        }
        let row: ReplyRow = try await supabase
            .from("replies")
            .insert(NewReply(question_id: questionId, author_id: uid.uuidString, body: body))
            .select(columns)
            .single()
            .execute()
            .value
        return row.toReplyItem(currentUserId: uid)
    }
}
