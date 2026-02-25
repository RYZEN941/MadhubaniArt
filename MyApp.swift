import SwiftUI

@main
struct MyApp: App {
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasFinishedOnboarding {
                HomeView()
            } else {
                OnboardingView(hasFinishedOnboarding: $hasFinishedOnboarding)
            }
        }
    }
}
