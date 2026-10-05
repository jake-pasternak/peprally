import Foundation

/// Connection details for the Supabase backend.
///
/// Copy this file to `SupabaseConfig.swift` (git-ignored) and fill in your
/// project URL and publishable key. The demo target never calls the backend,
/// so it runs with these placeholders as they are.
///
/// The anon key is a *publishable* client key — it's designed to ship inside
/// the app, and Row Level Security is what actually protects the data. Never
/// put the `service_role` key here.
enum SupabaseConfig {
    static let url = URL(string: "https://REPLACE_ME.supabase.co")!
    static let anonKey = "REPLACE_ME"
}
