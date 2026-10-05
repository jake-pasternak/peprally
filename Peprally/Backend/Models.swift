import Foundation

/// A row from `public.profiles`. Explicit CodingKeys map snake_case columns.
struct Profile: Codable {
    let id: UUID
    var handle: String?
    var avatarUrl: String?
    var isProfessional: Bool
    var verificationStatus: String
    var credential: String?
    var isModerator: Bool
    var modApplicationStatus: String?
    var setupDone: Bool
    var pushReplies: Bool
    var pushMentions: Bool
    var pushWeekly: Bool

    enum CodingKeys: String, CodingKey {
        case id, handle, credential
        case avatarUrl = "avatar_url"
        case isProfessional = "is_professional"
        case verificationStatus = "verification_status"
        case isModerator = "is_moderator"
        case modApplicationStatus = "mod_application_status"
        case setupDone = "setup_done"
        case pushReplies = "push_replies"
        case pushMentions = "push_mentions"
        case pushWeekly = "push_weekly"
    }
}

/// A row from `public.topics` (the peptide catalog).
struct Topic: Codable, Identifiable {
    let id: UUID
    let slug: String
    let name: String
    let hex: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, slug, name, hex
        case sortOrder = "sort_order"
    }
}
