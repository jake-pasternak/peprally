import XCTest
@testable import Peprally

/// Decodes PostgREST-shaped JSON (the same embeds FeedService/ReplyService
/// select) and checks what the feed and thread views end up showing.
final class RowMappingTests: XCTestCase {

    private let me = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let other = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    private func question(author: UUID, authorJSON: String, topicJSON: String) throws -> QuestionRow {
        let json = """
        {
          "id": "6F1D7C1E-1111-4C2B-9E0B-3E6B1E2D9A01",
          "author_id": "\(author.uuidString)",
          "title": "BPC-157 oral vs injected?",
          "body": "Has anyone compared them?",
          "like_count": 4,
          "reply_count": 2,
          "created_at": "2026-07-14T19:44:54.123456+00:00",
          "author": \(authorJSON),
          "topic": \(topicJSON)
        }
        """
        return try JSONDecoder().decode(QuestionRow.self, from: Data(json.utf8))
    }

    private let verifiedAuthor = """
    {"handle": "drpriyanair", "avatar_url": null, "is_professional": true,
     "verification_status": "verified", "credential": "Endocrinologist", "is_moderator": false}
    """

    func testVerifiedAuthorGetsCredentialBadge() throws {
        let row = try question(author: other, authorJSON: verifiedAuthor,
                               topicJSON: #"{"name": "BPC-157", "hex": "E3EEF9"}"#)
        let feed = row.toFeed(currentUserId: me)

        guard case .verified(let credential)? = feed.badge else {
            return XCTFail("expected a verified badge, got \(String(describing: feed.badge))")
        }
        XCTAssertEqual(credential, "Endocrinologist")
        XCTAssertEqual(feed.topic, "BPC-157")
        XCTAssertEqual(feed.hex, 0xE3EEF9)
        XCTAssertEqual(feed.answers, 2)
        XCTAssertEqual(feed.likes, 4)
        XCTAssertFalse(feed.isMine)
    }

    /// Claiming to be a professional is not the same as being verified.
    func testPendingOrSelfDeclaredProfessionalGetsNoBadge() throws {
        let pending = """
        {"handle": "rn_dayshift", "avatar_url": null, "is_professional": true,
         "verification_status": "pending", "credential": "Physician", "is_moderator": false}
        """
        let row = try question(author: other, authorJSON: pending, topicJSON: "null")
        XCTAssertNil(row.toFeed(currentUserId: me).badge)
    }

    func testMissingEmbedsFallBackToDefaults() throws {
        let row = try question(author: me, authorJSON: "null", topicJSON: "null")
        let feed = row.toFeed(currentUserId: me)
        XCTAssertEqual(feed.author, "member")
        XCTAssertEqual(feed.topic, "General")
        XCTAssertTrue(feed.isMine)
    }

    func testReplyMapsLikesToVouches() throws {
        let json = """
        {"id": "9A0B4C11-2222-4C2B-9E0B-3E6B1E2D9A02",
         "author_id": "\(me.uuidString)", "body": "Ask your prescriber.",
         "like_count": 7, "created_at": "2026-07-14T19:44:54+00:00",
         "author": \(verifiedAuthor)}
        """
        let reply = try JSONDecoder().decode(ReplyRow.self, from: Data(json.utf8))
            .toReplyItem(currentUserId: me)
        XCTAssertEqual(reply.vouches, 7)
        XCTAssertEqual(reply.author, "drpriyanair")
        XCTAssertTrue(reply.isMine)
    }
}
