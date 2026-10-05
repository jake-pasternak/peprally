import Foundation
import Supabase

/// Thin wrapper over Supabase auth. The profile row is created automatically
/// by the `handle_new_user` trigger the first time a user signs in.
enum AuthService {
    /// Exchange an Apple identity token for a Supabase session.
    static func signInWithApple(idToken: String, nonce: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    static func signOut() async {
        try? await supabase.auth.signOut()
    }

    /// Erase the signed-in user's account and all their content (App Store
    /// 5.1.1(v)); the DB function cascades the delete, then we drop the session.
    static func deleteAccount() async throws {
        try await supabase.rpc("delete_my_account").execute()
        try? await supabase.auth.signOut()
    }
}
