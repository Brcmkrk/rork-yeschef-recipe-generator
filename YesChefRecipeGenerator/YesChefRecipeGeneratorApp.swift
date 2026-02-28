import SwiftUI

@main
struct YesChefRecipeGeneratorApp: App {
    @State private var likesStore = LikesStore()
    @State private var languageManager = LanguageManager()
    @State private var triedRecipesStore = TriedRecipesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(likesStore)
                .environment(languageManager)
                .environment(triedRecipesStore)
        }
    }
}
