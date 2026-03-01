import SwiftUI

@Observable
class RecipeViewModel {
    var ingredientsText: String = ""
    var selectedCuisines: Set<Cuisine> = []
    var servings: Int = 2
    var exactMatchRecipes: [Recipe] = []
    var extraIngredientRecipes: [Recipe] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var hasResults: Bool = false
    private var generationTask: Task<Void, Never>?

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

    func translateIfNeeded(to newLanguage: String) {
        guard newLanguage != language else { return }
        let oldLanguage = language
        language = newLanguage
        guard hasResults, !exactMatchRecipes.isEmpty || !extraIngredientRecipes.isEmpty else { return }
        guard (exactMatchRecipes.first?.language ?? oldLanguage) != newLanguage else { return }

        isTranslating = true
        Task {
            do {
                if !exactMatchRecipes.isEmpty {
                    let translated = try await OpenAIService.shared.translateRecipes(exactMatchRecipes, to: newLanguage)
                    exactMatchRecipes = translated.map { var r = $0; r.language = newLanguage; return r }
                }
                if !extraIngredientRecipes.isEmpty {
                    let translated = try await OpenAIService.shared.translateRecipes(extraIngredientRecipes, to: newLanguage)
                    extraIngredientRecipes = translated.map { var r = $0; r.language = newLanguage; return r }
                }
            } catch {
                // keep originals on failure
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

    func generateRecipes() async {
        guard canGenerate else { return }

        isLoading = true
        errorMessage = nil

        do {
            let cuisineNames = selectedCuisines.map { $0.localizedName(language: language) }
            let response = try await OpenAIService.shared.generateRecipes(
                ingredients: ingredientsList,
                cuisines: cuisineNames,
                servings: servings,
                language: language
            )

            exactMatchRecipes = response.exact_match_recipes.map { var r = $0; r.language = language; return r }
            extraIngredientRecipes = response.extra_ingredient_recipes.map { var r = $0; r.language = language; return r }
            hasResults = true
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

        if !recipe.spices_common.isEmpty {
            text += "\n\n🧂 Common Spices:\n  \(recipe.spices_common.joined(separator: ", "))"
        }

        if !recipe.spices_optional.isEmpty {
            text += "\n\n✨ Optional Spices:\n  \(recipe.spices_optional.joined(separator: ", "))"
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
