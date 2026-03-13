import Foundation

@Observable
class TriedRecipesStore {
    var recipes: [Recipe] = []
    var isTranslating: Bool = false
    private let key = "tried_recipes"

    init() {
        loadLocal()
        Task { await syncFromSupabase() }
    }

    func add(_ recipe: Recipe) {
        StatsStore.shared.incrementTried()
        if !recipes.contains(where: { $0.id == recipe.id }) {
            if !SubscriptionManager.shared.isProUser {
                FreeRecipeTracker.shared.incrementUsage()
            }
            recipes.insert(recipe, at: 0)
            saveLocal()
        }
        let recipeCopy = recipe
        Task {
            do {
                try await SupabaseService.shared.upsertTriedRecipe(recipe: recipeCopy)
            } catch {
                print("[TriedRecipesStore] Failed to save: \(error.localizedDescription)")
            }
        }
    }

    func remove(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        var hidden = UserDefaults.standard.stringArray(forKey: "hidden_tried_recipes") ?? []
        if !hidden.contains(recipe.id) {
            hidden.append(recipe.id)
        }
        UserDefaults.standard.set(hidden, forKey: "hidden_tried_recipes")
        saveLocal()
    }

    func contains(_ id: String) -> Bool {
        recipes.contains(where: { $0.id == id })
    }

    func syncFromSupabase() async {
        guard SupabaseService.shared.isConfigured else { return }
        do {
            let remote = try await SupabaseService.shared.fetchMyTriedRecipes()
            var synced: [Recipe] = []
            let hiddenIds = Set(UserDefaults.standard.stringArray(forKey: "hidden_tried_recipes") ?? [])

            for r in remote {
                if !hiddenIds.contains(r.recipe_id),
                   let recipe = r.recipe_data.toRecipe() {
                    synced.append(recipe)
                }
            }

            let localOnly = recipes.filter { local in
                !synced.contains(where: { $0.id == local.id }) && !hiddenIds.contains(local.id)
            }
            for recipe in localOnly {
                try? await SupabaseService.shared.upsertTriedRecipe(recipe: recipe)
                synced.append(recipe)
            }

            recipes = synced
            saveLocal()
        } catch {
            // keep local
        }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = decoded
    }

    func translateRecipes(to language: String) {
        guard !recipes.isEmpty else { return }
        let toTranslate = recipes.filter { ($0.language ?? "") != language }
        guard !toTranslate.isEmpty else { return }
        isTranslating = true
        Task {
            do {
                let translated = try await OpenAIService.shared.translateRecipes(toTranslate, to: language)
                for t in translated {
                    if let idx = recipes.firstIndex(where: { $0.id == t.id }) {
                        var updated = t
                        updated.language = language
                        recipes[idx] = updated
                    }
                }
                saveLocal()
            } catch {
                print("TriedRecipesStore translation error: \(error.localizedDescription)")
            }
            isTranslating = false
        }
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
