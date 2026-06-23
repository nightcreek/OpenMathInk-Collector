import SwiftUI

@main
struct OpenMathInkCollectorApp: App {
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @ObservedObject private var consentManager = ContributorConsentManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AppRootView()
                
                if onboardingManager.shouldShowOnboarding {
                    OnboardingView(isPresented: $onboardingManager.shouldShowOnboarding)
                        .environmentObject(consentManager)
                }
            }
            .environmentObject(onboardingManager)
            .environmentObject(consentManager)
        }
    }
}
