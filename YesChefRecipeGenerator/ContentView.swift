import SwiftUI

struct ContentView: View {
    @State private var viewModel = RecipeViewModel()
    @State private var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
                withAnimation(.spring(duration: 0.5)) {
                    hasSeenOnboarding = true
                }
            }
        } else {
            TabView {
                Tab(lang.t("Home", "Ana Sayfa"), systemImage: "frying.pan.fill") {
                    HomeView(viewModel: viewModel)
                }
                Tab(lang.t("Profile", "Profil"), systemImage: "person.fill") {
                    ProfileView()
                }
            }
            .tint(.orange)
        }
    }
}
