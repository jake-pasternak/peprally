import Foundation
import Supabase

/// Reads and writes questions (the feed).
enum FeedService {
    static let columns = """
    id,author_id,title,body,like_count,reply_count,created_at,\
    author:profiles!author_id(handle,avatar_url,is_professional,verification_status,credential,is_moderator),\
    topic:topics(name,hex)
    """

    /// The newest questions, mapped for the feed.
    static func fetch(limit: Int = 50) async throws -> [FeedQuestion] {
        let uid = currentUserId
        let rows: [QuestionRow] = try await supabase
            .from("questions")
            .select(columns)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.map { $0.toFeed(currentUserId: uid) }
    }

    /// Insert a question and return it as a feed item.
    static func create(title: String, body: String, topicName: String) async throws -> FeedQuestion {
        guard let uid = currentUserId else { throw BackendError.notAuthenticated }
        let topicId = try? await topicId(named: topicName)

        struct NewQuestion: Encodable {
            let author_id: String
            let topic_id: String?
            let title: String
            let body: String
        }
        let row: QuestionRow = try await supabase
            .from("questions")
            .insert(NewQuestion(author_id: uid.uuidString, topic_id: topicId,
                                title: title, body: body))
            .select(columns)
            .single()
            .execute()
            .value
        return row.toFeed(currentUserId: uid)
    }

    static func delete(id: String) async throws {
        try await supabase.from("questions").delete().eq("id", value: id).execute()
    }

    private static func topicId(named name: String) async throws -> String? {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await supabase
            .from("topics").select("id").eq("name", value: name).limit(1)
            .execute().value
        return rows.first?.id.uuidString
    }
}
