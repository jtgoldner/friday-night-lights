import SwiftUI

@main
struct FridayNightLightsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.zipCode.isEmpty {
                OnboardingView()
                    .environmentObject(appState)
            } else {
                HomeView()
                    .environmentObject(appState)
            }
        }
    }
}
