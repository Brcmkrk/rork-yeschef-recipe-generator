import SwiftUI

@Observable
class FreeRecipeTracker {
    static let shared = FreeRecipeTracker()

    private let maxFreeRecipes = 3
    private let key = "free_recipe_count"

    var usedRecipes: Int {
        didSet {
            UserDefaults.standard.set(usedRecipes, forKey: key)
        }
    }

    var remainingFreeRecipes: Int {
        max(0, maxFreeRecipes - usedRecipes)
    }

    var hasReachedLimit: Bool {
        usedRecipes >= maxFreeRecipes
    }

    private init() {
        self.usedRecipes = UserDefaults.standard.integer(forKey: key)
    }

    func incrementUsage() {
        usedRecipes += 1
    }
}
