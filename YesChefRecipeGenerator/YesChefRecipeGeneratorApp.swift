import SwiftUI
import RevenueCat
import GoogleMobileAds

@main
struct YesChefRecipeGeneratorApp: App {
    @State private var likesStore = LikesStore()
    @State private var languageManager = LanguageManager()
    @State private var triedRecipesStore = TriedRecipesStore()
    @State private var statsStore = StatsStore.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var freeRecipeTracker = FreeRecipeTracker.shared
    @State private var interstitialAdManager = InterstitialAdManager.shared

    init() {
        SubscriptionManager.shared.configure()
        GADMobileAds.sharedInstance().start { _ in
            InterstitialAdManager.shared.loadAd()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(likesStore)
                .environment(languageManager)
                .environment(triedRecipesStore)
                .environment(statsStore)
                .environment(subscriptionManager)
                .environment(freeRecipeTracker)
                .environment(interstitialAdManager)
        }
    }
}
