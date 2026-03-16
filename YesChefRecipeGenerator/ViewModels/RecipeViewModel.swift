import SwiftUI

@Observable
class RecipeViewModel {
    var ingredientsText: String = ""
    var selectedIngredients: [String] = []
    var selectedCuisines: Set<Cuisine> = []
    var selectedCuisine: Cuisine?
    var servings: Int = 2
    var exactMatchCount: Int = 2
    var extraIngredientCount: Int = 2
    var useStrictMatch: Bool = false
    var exactMatchRecipes: [Recipe] = []
    var extraIngredientRecipes: [Recipe] = []
    var isLoading: Bool = false
    var isExpanding: Bool = false
    var isNearMatch: Bool = false
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

    var canGenerateFromFlow: Bool {
        !selectedIngredients.isEmpty && selectedCuisine != nil && !isLoading
    }

    func syncFlowToGeneration() {
        ingredientsText = selectedIngredients.joined(separator: ", ")
        if let cuisine = selectedCuisine {
            selectedCuisines = [cuisine]
        }
        if useStrictMatch {
            exactMatchCount = 4
            extraIngredientCount = 0
        } else {
            exactMatchCount = 2
            extraIngredientCount = 2
        }
    }

    func addIngredient(_ ingredient: String) {
        let trimmed = ingredient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedIngredients.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        selectedIngredients.append(trimmed)
    }

    func removeIngredient(_ ingredient: String) {
        selectedIngredients.removeAll { $0 == ingredient }
    }

    func fillRandomIngredients(language: String) {
        selectedIngredients = IngredientPool.random(count: Int.random(in: 4...7), language: language)
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

    private let maxRetries: Int = 3

    func generatePreviews(excludeTitles: [String] = []) async {
        guard canGenerate else { return }

        if excludeTitles.isEmpty {
            previousRecipeTitles = []
        }

        isLoading = true
        isExpanding = false
        isNearMatch = false
        errorMessage = nil

        let cuisineNames = selectedCuisines.map { $0.localizedName(language: language) }

        for attempt in 1...maxRetries {
            do {
                let response = try await OpenAIService.shared.generatePreviews(
                    ingredients: ingredientsList,
                    cuisines: cuisineNames,
                    servings: servings,
                    language: language,
                    exactCount: exactMatchCount,
                    extraCount: extraIngredientCount,
                    excludeTitles: excludeTitles
                )

                var exact = response.exact_match_recipes.prefix(exactMatchCount).map { var r = $0; r.language = language; return r }
                let extra = response.extra_ingredient_recipes.prefix(extraIngredientCount).map { var r = $0; r.language = language; return r }

                if exact.isEmpty && extra.isEmpty {
                    print("[RecipeVM] Attempt \(attempt)/\(maxRetries): empty results, retrying...")
                    if attempt < maxRetries {
                        try await Task.sleep(for: .seconds(1))
                        continue
                    }
                    isLoading = false
                    errorMessage = language == "tr"
                        ? "Tarif oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin."
                        : "Something went wrong generating recipes. Please try again."
                    return
                }

                if exact.isEmpty && !extra.isEmpty {
                    isNearMatch = true
                    let nearCount = min(exactMatchCount, extra.count)
                    exact = Array(extra.prefix(nearCount))
                    print("[RecipeVM] No exact match found, promoting \(nearCount) extra recipes as near-match")
                }

                exactMatchRecipes = Array(exact)
                extraIngredientRecipes = Array(extra.filter { e in !exact.contains(where: { $0.id == e.id }) })
                isLoading = false

                print("[RecipeVM] Previews loaded (attempt \(attempt)): \(exactMatchRecipes.count) exact/near + \(extraIngredientRecipes.count) extra, nearMatch=\(isNearMatch)")

                hasResults = true
                expandRecipesInBackground()
                return
            } catch is CancellationError {
                isLoading = false
                return
            } catch {
                print("[RecipeVM] Attempt \(attempt)/\(maxRetries) error: \(error.localizedDescription)")
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                let msg = error.localizedDescription
                if msg.contains("unreachable") || msg.contains("not deployed") || msg.contains("API key not configured") {
                    errorMessage = language == "tr"
                        ? "Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin."
                        : "Could not connect to server. Please check your connection and try again."
                } else {
                    errorMessage = msg
                }
                isLoading = false
                return
            }
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
