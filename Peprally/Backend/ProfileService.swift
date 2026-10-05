import Foundation
import Supabase

/// One of the user's replies, with the question it answered (for tap-through).
struct MyReply: Identifiable {
    let id = UUID()
    let to: String
    let text: String
    let time: String
    let parent: FeedQuestion?
}

/// Reads and writes the signed-in user's profile row.
enum ProfileService {
    /// The current user's profile. The `handle_new_user` trigger is supposed
    /// to create this row on signup, but we don't depend on it: we upsert our
    /// own row first (a no-op if it already exists) so a fresh Apple sign-in
    /// can never fail with "cannot coerce the result to a single JSON object"
    /// just because the trigger didn't fire.
    static func fetchMine() async throws -> Profile {
        guard let uid = currentUserId else { throw BackendError.notAuthenticated }
        try? await ensureProfileRow(uid: uid)
        return try await supabase
            .from("profiles")
            .select()
            .eq("id", value: uid.uuidString)
            .single()
            .execute()
            .value
    }

    /// Guarantee the signed-in user has a profile row. RLS ("insert own
    /// profile", check id = auth.uid()) allows the client to create its own;
    /// `ignoreDuplicates` makes it a safe no-op when the row already exists.
    static func ensureProfileRow(uid: UUID? = nil) async throws {
        guard let uid = uid ?? currentUserId else { throw BackendError.notAuthenticated }
        struct NewProfile: Encodable { let id: String }
        try await supabase
            .from("profiles")
            .upsert(NewProfile(id: uid.uuidString), onConflict: "id", ignoreDuplicates: true)
            .execute()
    }

    /// Whether a handle is free. Handles are stored lowercase (the input field
    /// enforces it), so an exact match is a correct case-insensitive check —
    /// and your own current handle counts as available.
    static func isHandleAvailable(_ handle: String) async -> Bool {
        let h = handle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.count >= 3 else { return false }
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await supabase
            .from("profiles").select("id")
            .eq("handle", value: h)
            .limit(1)
            .execute().value) ?? []
        return rows.isEmpty || rows.first?.id == currentUserId
    }

    /// The user's own questions, newest first (for the profile Questions tab).
    static func myQuestions() async throws -> [FeedQuestion] {
        guard let uid = currentUserId else { return [] }
        let rows: [QuestionRow] = try await supabase
            .from("questions")
            .select(FeedService.columns)
            .eq("author_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .execute().value
        return rows.map { $0.toFeed(currentUserId: uid) }
    }

    /// The user's own replies, newest first, each with the question it answered.
    static func myReplies() async throws -> [MyReply] {
        guard let uid = currentUserId else { return [] }
        struct Row: Decodable { let body: String; let created_at: String; let question: QuestionRow? }
        let rows: [Row] = try await supabase
            .from("replies")
            .select("body,created_at,question:questions(\(FeedService.columns))")
            .eq("author_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .execute().value
        return rows.map {
            MyReply(to: $0.question?.title ?? "a question",
                    text: $0.body,
                    time: DisplayFormat.relative($0.created_at),
                    parent: $0.question?.toFeed(currentUserId: uid))
        }
    }

    /// Persist the onboarding draft and mark setup complete.
    static func completeSetup(handle: String, isProfessional: Bool) async throws {
        struct Update: Encodable {
            let handle: String
            let is_professional: Bool
            let setup_done: Bool
        }
        guard let uid = currentUserId else { throw BackendError.notAuthenticated }
        try await supabase
            .from("profiles")
            .update(Update(handle: handle, is_professional: isProfessional, setup_done: true))
            .eq("id", value: uid.uuidString)
            .execute()
        // TODO(phase 3): persist followed topics into topic_follows once the
        // client peptide list is reconciled with the seeded topic catalog.
    }
}
