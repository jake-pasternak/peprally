import SwiftUI
import Observation

/// The post-auth setup steps, in order.
enum SetupStep: Int, CaseIterable, Equatable {
    case handle, peptides, professional, notifications
}

/// The credential-verification steps (professionals only, post-setup).
enum VerifyStep: Equatable {
    case intro, credentials, review
}

/// Where the user is in the app. One value drives the whole root.
enum AppStage: Equatable {
    case loading
    case welcome
    case setup(SetupStep)
    case verify(VerifyStep)
    case home
}

/// Single source of truth for routing and the profile draft collected
/// during onboarding. Backed by Supabase: session restore on launch, Apple
/// sign-in, and profile reads/writes.
@MainActor
@Observable
final class AppModel {
    var stage: AppStage = .loading

    // profile draft / loaded profile
    var handle = ""
    var phone = ""
    var followedPeptides: Set<String> = []
    var isProfessional = false
    var isModerator = false
    /// set when credentials are submitted; the badge appears on approval
    var verificationPending = false
    /// set when a moderator application is submitted — a volunteer role,
    /// reviewed separately from professional verification
    var modApplicationPending = false
    /// surfaced to the sign-in UI when auth fails (nil = no error)
    var authError: String?

    /// Runs behind the loading screen: restore any Supabase session, held to
    /// a ~2s beat so the mark completes its blink before the app opens.
    func start() async {
        async let beat: Void = Task.sleep(for: .seconds(2.0))

        // dev hooks bypass auth so UI can be driven without signing in
        if let hooked = devHookStage() {
            _ = try? await beat
            withAnimation(.easeInOut(duration: 0.9)) { stage = hooked }
            return
        }

        // Route by an actual authenticated read, run OFF the main thread
        // (reading supabase.auth.currentSession on main does blocking Keychain
        // I/O + a session decode). We only land on home/setup when the session
        // is real and valid — a stale/expired one fails here and drops to
        // welcome, instead of a zombie "signed-in" home where every write 401s.
        var next: AppStage = .welcome
        if let profile = try? await ProfileService.fetchMine() {
            apply(profile)
            next = profile.setupDone ? .home : .setup(.handle)
        }

        _ = try? await beat
        withAnimation(.easeInOut(duration: 0.9)) { stage = next }
    }

    /// Exchange an Apple identity token for a session, then route by whether
    /// setup has been completed. Both the sign-up and sign-in buttons call
    /// this — the profile state decides the destination, not the button.
    func handleAppleSignIn(idToken: String, nonce: String) async {
        do {
            try await AuthService.signInWithApple(idToken: idToken, nonce: nonce)
            let profile = try await ProfileService.fetchMine()
            apply(profile)
            withAnimation(.easeInOut(duration: 0.5)) {
                stage = profile.setupDone ? .home : .setup(.handle)
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func advanceSetup(from step: SetupStep) {
        if let next = SetupStep(rawValue: step.rawValue + 1) {
            stage = .setup(next)
        } else {
            let h = handle, pro = isProfessional
            Task { try? await ProfileService.completeSetup(handle: h, isProfessional: pro) }
            // professionals get offered verification before landing; it
            // never blocks — every path out of it leads home
            stage = isProfessional ? .verify(.intro) : .home
        }
    }

    func advanceVerify(to step: VerifyStep?) {
        stage = step.map(AppStage.verify) ?? .home
    }

    func backSetup(from step: SetupStep) {
        guard let prev = SetupStep(rawValue: step.rawValue - 1) else { return }
        stage = .setup(prev)
    }

    func signOut() {
        Task { await AuthService.signOut() }
        resetProfile()
        stage = .welcome
    }

    func deleteAccount() {
        Task { try? await AuthService.deleteAccount() }
        resetProfile()
        stage = .welcome
    }

    /// Demo-build entry: fill the account from the fixtures and open the feed.
    /// Used by the welcome screen's sign-in button, which has no real auth to
    /// call in that build.
    func enterDemo() {
        handle = SampleData.myHandle
        phone = SampleData.myPhone
        followedPeptides = SampleData.myFollowedTopics
        withAnimation(.easeInOut(duration: 0.5)) { stage = .home }
    }

    // MARK: - helpers

    private func apply(_ profile: Profile) {
        handle = profile.handle ?? ""
        isProfessional = profile.isProfessional
        isModerator = profile.isModerator
        verificationPending = profile.verificationStatus == "pending"
        modApplicationPending = profile.modApplicationStatus == "pending"
    }

    private func resetProfile() {
        handle = ""; followedPeptides = []; isProfessional = false
        isModerator = false; verificationPending = false; modApplicationPending = false
    }

    /// SETUP_STEP / GO_HOME / MOD env hooks for driving the UI without auth.
    private func devHookStage() -> AppStage? {
        let env = ProcessInfo.processInfo.environment
        if env["MOD"] != nil { isModerator = true }
        // fixtures on = no real session, so fill the account the profile and
        // settings read from (handle, followed topics) instead of showing blanks
        if SampleData.on {
            handle = SampleData.myHandle
            phone = SampleData.myPhone
            followedPeptides = SampleData.myFollowedTopics
        }
        #if DEMO
        // the demo build has no session and no Sign in with Apple entitlement —
        // it opens on the feed, after the loading mark, every launch
        return .home
        #endif
        if env["GO_HOME"] != nil { return .home }
        if let raw = env["SETUP_STEP"], let v = Int(raw), let s = SetupStep(rawValue: v) {
            return .setup(s)
        }
        return nil
    }
}
