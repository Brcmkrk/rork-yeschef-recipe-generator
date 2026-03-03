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

            let response = try await OpenAIService.shared.generateRecipes(
                ingredients: ingredientsList,
                cuisines: cuisineNames,
                servings: servings,
                language: language,
                exactCount: exactMatchCount,
                extraCount: extraIngredientCount,
                excludeTitles: excludeTitles
            )

            exactMatchRecipes = response.exact_match_recipes.prefix(exactMatchCount).map { var r = $0; r.language = language; return r }
            extraIngredientRecipes = response.extra_ingredient_recipes.prefix(extraIngredientCount).map { var r = $0; r.language = language; return r }

            let cacheInfo = response._cache
            cachedCount = cacheInfo?.cached_count ?? 0
            hasResults = true

            print("[RecipeVM] Result: \(cachedCount) from cache, \(cacheInfo?.fresh_count ?? 0) from AI")
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
