import SwiftUI

@Observable
class RecipeViewModel {
    var ingredientsText: String = ""
    var selectedCuisines: Set<Cuisine> = []
    var servings: Int = 2
    var exactMatchCount: Int = 2
    var extraIngredientCount: Int = 2
    var exactMatchRecipes: [Recipe] = []
    var extraIngredientRecipes: [Recipe] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var hasResults: Bool = false
    var cachedCount: Int = 0
    private var generationTask: Task<Void, Never>?
    private var previousRecipeTitles: [String] = []

    var ingredientsList: [String] {
        ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var canGenerate: Bool {
        !ingredientsList.isEmpty && !selectedCuisines.isEmpty && !isLoading
    }

    var language: String = "en"
    var isTranslating: Bool = false
    var translationError: String?

    func translateIfNeeded(to newLanguage: String) {
        language = newLanguage
        guard hasResults, !exactMatchRecipes.isEmpty || !extraIngredientRecipes.isEmpty else { return }

        let exactNeedsTranslation = exactMatchRecipes.contains { ($0.language ?? "") != newLanguage }
        let extraNeedsTranslation = extraIngredientRecipes.contains { ($0.language ?? "") != newLanguage }
        guard exactNeedsTranslation || extraNeedsTranslation else { return }

        isTranslating = true
        translationError = nil
        Task {
            do {
                if exactNeedsTranslation && !exactMatchRecipes.isEmpty {
                    let toTranslate = exactMatchRecipes.filter { ($0.language ?? "") != newLanguage }
                    let ids = toTranslate.map { $0.id }

                    if let cached = RecipeCacheService.shared.cachedTranslation(for: ids, language: newLanguage) {
                        for t in cached {
                            if let idx = exactMatchRecipes.firstIndex(where: { $0.id == t.id }) {
                                var updated = t
                                updated.language = newLanguage
                                exactMatchRecipes[idx] = updated
                            }
                        }
                    } else {
                        let translated = try await OpenAIService.shared.translateRecipes(toTranslate, to: newLanguage)
                        RecipeCacheService.shared.storeTranslation(translated, recipeIDs: ids, language: newLanguage)
                        for t in translated {
                            if let idx = exactMatchRecipes.firstIndex(where: { $0.id == t.id }) {
                                var updated = t
                                updated.language = newLanguage
                                exactMatchRecipes[idx] = updated
                            }
                        }
                    }
                }
                if extraNeedsTranslation && !extraIngredientRecipes.isEmpty {
                    let toTranslate = extraIngredientRecipes.filter { ($0.language ?? "") != newLanguage }
                    let ids = toTranslate.map { $0.id }

                    if let cached = RecipeCacheService.shared.cachedTranslation(for: ids, language: newLanguage) {
                        for t in cached {
                            if let idx = extraIngredientRecipes.firstIndex(where: { $0.id == t.id }) {
                                var updated = t
                                updated.language = newLanguage
                                extraIngredientRecipes[idx] = updated
                            }
                        }
                    } else {
                        let translated = try await OpenAIService.shared.translateRecipes(toTranslate, to: newLanguage)
                        RecipeCacheService.shared.storeTranslation(translated, recipeIDs: ids, language: newLanguage)
                        for t in translated {
                            if let idx = extraIngredientRecipes.firstIndex(where: { $0.id == t.id }) {
                                var updated = t
                                updated.language = newLanguage
                                extraIngredientRecipes[idx] = updated
                            }
                        }
                    }
                }
            } catch {
                translationError = error.localizedDescription
            }
            isTranslating = false
        }
    }

    func fillRandom() {
        ingredientsText = IngredientPool.random(count: Int.random(in: 4...7), language: language).joined(separator: ", ")
    }

    func selectAllCuisines() {
        selectedCuisines = Set(Cuisine.allCases)
    }

    func clearCuisines() {
        selectedCuisines.removeAll()
    }

    func toggleCuisine(_ cuisine: Cuisine) {
        if selectedCuisines.contains(cuisine) {
            selectedCuisines.remove(cuisine)
        } else {
            selectedCuisines.insert(cuisine)
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isLoading = false
    }

    func refreshRecipes() async {
        let currentTitles = (exactMatchRecipes + extraIngredientRecipes).map { $0.title }
        previousRecipeTitles.append(contentsOf: currentTitles)
        await generateRecipes(excludeTitles: previousRecipeTitles)
    }

    func generateRecipes(excludeTitles: [String] = []) async {
        guard canGenerate else { return }

        if excludeTitles.isEmpty {
            previousRecipeTitles = []
        }

        isLoading = true
        errorMessage = nil

        do {
            let cuisineNames = selectedCuisines.map { $0.localizedName(language: language) }
            let totalNeeded = exactMatchCount + extraIngredientCount

            var cachedRecipes: [Recipe] = []
            let maxFromCache = totalNeeded / 2

            if SupabaseService.shared.isConfigured {
                let candidates = await SupabaseService.shared.fetchCachedRecipes(
                    ingredients: ingredientsList,
                    servings: servings,
                    cuisines: cuisineNames,
                    language: language
                )
                let filtered = candidates.filter { !excludeTitles.contains($0.title) }
                cachedRecipes = Array(filtered.shuffled().prefix(maxFromCache))
            }

            let cachedExact = cachedRecipes.filter { $0.required_extra_ingredients.isEmpty }
            let cachedExtra = cachedRecipes.filter { !$0.required_extra_ingredients.isEmpty }

            let neededExact = max(0, exactMatchCount - cachedExact.count)
            let neededExtra = max(0, extraIngredientCount - cachedExtra.count)

            var aiExact: [Recipe] = []
            var aiExtra: [Recipe] = []

            if neededExact > 0 || neededExtra > 0 {
                let allExclude = excludeTitles + cachedRecipes.map { $0.title }
                let response = try await OpenAIService.shared.generateRecipes(
                    ingredients: ingredientsList,
                    cuisines: cuisineNames,
                    servings: servings,
                    language: language,
                    exactCount: neededExact,
                    extraCount: neededExtra,
                    excludeTitles: allExclude
                )
                aiExact = response.exact_match_recipes
                aiExtra = response.extra_ingredient_recipes
            }

            let finalExact = (cachedExact + aiExact).prefix(exactMatchCount)
            let finalExtra = (cachedExtra + aiExtra).prefix(extraIngredientCount)

            exactMatchRecipes = finalExact.map { var r = $0; r.language = language; return r }
            extraIngredientRecipes = finalExtra.map { var r = $0; r.language = language; return r }
            cachedCount = cachedRecipes.count
            hasResults = true

            if cachedRecipes.count <= 1 {
                let aiRecipes = aiExact + aiExtra
                let toCache = Array(aiRecipes.shuffled().prefix(4))
                let cacheLang = language
                Task {
                    await SupabaseService.shared.saveRecipesToCache(toCache, language: cacheLang)
                }
            }
        } catch is CancellationError {
            // cancelled
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func copyRecipeText(_ recipe: Recipe) -> String {
        var text = """
        🍳 \(recipe.title)
        ━━━━━━━━━━━━━━━━━━
        Servings: \(recipe.servings)
        Cuisine: \(recipe.cuisine)
        Difficulty: \(recipe.difficulty)
        Calories: \(recipe.calories) kcal

        📋 Ingredients:
        """

        for ingredient in recipe.ingredients {
            text += "\n  • \(ingredient.quantity) \(ingredient.unit) \(ingredient.name)"
        }

        let allSpices = recipe.allSpices
        if !allSpices.isEmpty {
            text += "\n\n🧂 Spices:"
            for spice in allSpices {
                text += "\n  • \(spice.name)"
                if !spice.alternatives.isEmpty {
                    text += " (→ \(spice.alternatives.joined(separator: ", ")))"
                }
            }
        }

        if !recipe.required_extra_ingredients.isEmpty {
            text += "\n\n🛒 Extra Ingredients Needed:\n  \(recipe.required_extra_ingredients.joined(separator: ", "))"
        }

        text += "\n\n📝 Steps:"
        for (index, step) in recipe.steps.enumerated() {
            text += "\n  \(index + 1). \(step)"
        }

        return text
    }
}
