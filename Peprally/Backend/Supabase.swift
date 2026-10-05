import Foundation
import Supabase

/// The shared Supabase client — one instance for the whole app. Auth session
/// is persisted and refreshed automatically by the SDK.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)

enum BackendError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You're not signed in. Sign in with Apple, then try again."
        }
    }
}

/// The signed-in user's id, read from the *cached* session (no network). The
/// PostgREST client attaches the access token to requests on its own, so this
/// is only used to build row values — never worth a refreshing `auth.session`
/// round-trip on every call.
var currentUserId: UUID? { supabase.auth.currentUser?.id }
