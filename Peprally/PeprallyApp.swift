import SwiftUI

@main
struct PeprallyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

/// One switch over AppStage — loading, welcome, setup, home — with soft
/// crossfades between stages. No navigation stack anywhere.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // dev hook: render the design-system reference instead of the app
        if let page = ProcessInfo.processInfo.environment["DESIGN_GALLERY"] {
            DesignSystemGallery(page: page == "2" ? 2 : 1)
        } else {
            ZStack {
                // pages switch INSTANTLY — the motion lives inside each
                // page's entrance cascade, never between pages. The only
                // animated transition is the fade out of loading.
                switch model.stage {
                case .loading:
                    LoadingView().transition(.opacity)
                case .welcome:
                    WelcomeView().transition(.opacity)
                case .setup(let step):
                    SetupFlowView(step: step)
                case .verify(let step):
                    VerificationFlow(step: step)
                case .home:
                    HomeView().transition(.opacity)
                }
            }
            // solid floor under every crossfade: without it, two screens at
            // partial opacity compose over the black window and the whole
            // display dips dark mid-transition — the "lag" between screens
            .background(Color.white.ignoresSafeArea())
            .task { await model.start() }
        }
    }
}

/// The signed-out surface. One screen, one way in: Sign in with Apple both
/// creates the account and returns you to it, so there is no sign-up/sign-in
/// split and nothing to route between.
struct WelcomeView: View {
    var body: some View {
        AuthView()
    }
}
