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
    var isExpanding: Bool = false
    var cachedCount: Int = 0
    var errorMessage: String?
    var hasResults: Bool = false
    private var generationTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?
    private var expandQueue: [String] = []
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

    var allRecipesExpanded: Bool {
        let all = exactMatchRecipes + extraIngredientRecipes
        return !all.isEmpty && all.allSatisfy { $0.isFullyLoaded }
    }

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
        expandTask?.cancel()
        generationTask = nil
        expandTask = nil
        isLoading = false
        isExpanding = false
    }

    func refreshRecipes() async {
        let currentTitles = (exactMatchRecipes + extraIngredientRecipes).map { $0.title }
        previousRecipeTitles.append(contentsOf: currentTitles)
        await generatePreviews(excludeTitles: previousRecipeTitles)
    }

    func generatePreviews(excludeTitles: [String] = []) async {
        guard canGenerate else { return }

        if excludeTitles.isEmpty {
            previousRecipeTitles = []
        }

        isLoading = true
        isExpanding = false
        errorMessage = nil

        do {
            let cuisineNames = selectedCuisines.map { $0.localizedName(language: language) }

            let response = try await OpenAIService.shared.generatePreviews(
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

            hasResults = true
            isLoading = false

            print("[RecipeVM] Previews loaded: \(exactMatchRecipes.count) exact + \(extraIngredientRecipes.count) extra")

            expandRecipesInBackground()
        } catch is CancellationError {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func prioritizeRecipe(id: String) {
        guard !expandQueue.isEmpty else { return }
        guard let idx = expandQueue.firstIndex(of: id) else { return }
        expandQueue.remove(at: idx)
        expandQueue.insert(id, at: 0)
        print("[RecipeVM] Prioritized recipe: \(id)")
    }

    private func expandRecipesInBackground() {
        expandTask?.cancel()

        let allRecipes = exactMatchRecipes + extraIngredientRecipes
        guard !allRecipes.isEmpty else { return }

        expandQueue = allRecipes.map { $0.id }
        isExpanding = true

        expandTask = Task {
            while !expandQueue.isEmpty {
                guard !Task.isCancelled else { break }

                let nextId = expandQueue[0]
                let allCurrent = exactMatchRecipes + extraIngredientRecipes
                guard let recipe = allCurrent.first(where: { $0.id == nextId }) else {
                    expandQueue.removeFirst()
                    continue
                }

                if recipe.isFullyLoaded {
                    expandQueue.removeFirst()
                    continue
                }

                do {
                    let expanded = try await OpenAIService.shared.expandRecipes([recipe], language: language)

                    guard !Task.isCancelled else { break }

                    for detail in expanded {
                        if let idx = exactMatchRecipes.firstIndex(where: { $0.id == detail.id }) {
                            exactMatchRecipes[idx] = exactMatchRecipes[idx].applyExpansion(
                                steps: detail.steps,
                                spices: detail.spices
                            )
                        } else if let idx = extraIngredientRecipes.firstIndex(where: { $0.id == detail.id }) {
                            extraIngredientRecipes[idx] = extraIngredientRecipes[idx].applyExpansion(
                                steps: detail.steps,
                                spices: detail.spices
                            )
                        }
                    }

                    print("[RecipeVM] Expanded recipe: \(nextId)")
                } catch is CancellationError {
                    break
                } catch {
                    print("[RecipeVM] Expand error for \(nextId): \(error.localizedDescription)")
                }

                expandQueue.removeFirst()
            }

            isExpanding = false
        }
    }

    func generateRecipes(excludeTitles: [String] = []) async {
        await generatePreviews(excludeTitles: excludeTitles)
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
