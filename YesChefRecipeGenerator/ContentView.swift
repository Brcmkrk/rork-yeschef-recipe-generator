import SwiftUI

struct ContentView: View {
    @State private var viewModel = RecipeViewModel()
    @State private var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
    @State private var showInitialPaywall: Bool = false
    @Environment(LanguageManager.self) private var lang
    @Environment(SubscriptionManager.self) private var subscriptionManager

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
                Tab(lang.t("Home", "Ana Sayfa"), systemImage: "house.fill") {
                    HomeView(viewModel: viewModel)
                }
                Tab(lang.t("Profile", "Profil"), systemImage: "person.fill") {
                    ProfileView()
                }
                Tab(lang.t("Settings", "Ayarlar"), systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            .tint(.orange)
            .onAppear {
                if !subscriptionManager.isProUser && !UserDefaults.standard.bool(forKey: "has_seen_initial_paywall") {
                    showInitialPaywall = true
                }
            }
            .sheet(isPresented: $showInitialPaywall) {
                UserDefaults.standard.set(true, forKey: "has_seen_initial_paywall")
            } content: {
                PaywallView()
                    .interactiveDismissDisabled(false)
            }
        }
    }
}
