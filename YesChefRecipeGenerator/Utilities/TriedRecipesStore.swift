import Foundation

@Observable
class TriedRecipesStore {
    var recipes: [Recipe] = []
    private let key = "tried_recipes"

    init() {
        loadLocal()
        Task { await syncFromSupabase() }
    }

    func add(_ recipe: Recipe) {
        guard !recipes.contains(where: { $0.id == recipe.id }) else { return }
        recipes.insert(recipe, at: 0)
        saveLocal()
        Task { try? await SupabaseService.shared.upsertTriedRecipe(recipe: recipe) }
    }

    func remove(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        saveLocal()
        Task { try? await SupabaseService.shared.deleteTriedRecipe(recipeId: recipe.id) }
    }

    func contains(_ recipe: Recipe) -> Bool {
        recipes.contains(where: { $0.id == recipe.id })
    }

    func syncFromSupabase() async {
        guard SupabaseService.shared.isConfigured else { return }
        do {
            let remote = try await SupabaseService.shared.fetchMyTriedRecipes()
            var synced: [Recipe] = []

            for r in remote {
                if let recipeData = r.recipe_data.data(using: .utf8),
                   let recipe = try? JSONDecoder().decode(Recipe.self, from: recipeData) {
                    synced.append(recipe)
                }
            }

            let localOnly = recipes.filter { local in
                !synced.contains(where: { $0.id == local.id })
            }
            for recipe in localOnly {
                try? await SupabaseService.shared.upsertTriedRecipe(recipe: recipe)
                synced.append(recipe)
            }

            recipes = synced
            saveLocal()
        } catch {
            // keep local data on failure
        }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = decoded
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
