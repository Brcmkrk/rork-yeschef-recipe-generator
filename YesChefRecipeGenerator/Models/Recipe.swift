import Foundation

nonisolated struct RecipeSpice: Codable, Sendable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let alternatives: [String]
}

nonisolated struct RecipeIngredient: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(name)-\(quantity)-\(unit)" }
    let name: String
    let quantity: String
    let unit: String
}

nonisolated struct Recipe: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let calories: String
    let cuisine: String
    let difficulty: String
    let description: String
    let servings: Int
    let ingredients: [RecipeIngredient]
    let spices: [RecipeSpice]?
    let spices_common: [String]?
    let spices_optional: [String]?
    let required_extra_ingredients: [String]
    var steps: [String]
    var language: String?
    var source: String?
    var isExpanded: Bool?

    var isFullyLoaded: Bool {
        isExpanded == true || !steps.isEmpty
    }

    var allSpices: [RecipeSpice] {
        if let spices, !spices.isEmpty {
            return spices
        }
        var result: [RecipeSpice] = []
        for s in (spices_common ?? []) {
            result.append(RecipeSpice(name: s, alternatives: []))
        }
        for s in (spices_optional ?? []) {
            result.append(RecipeSpice(name: s, alternatives: []))
        }
        return result
    }

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.language == rhs.language
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(language)
    }

    mutating func applyExpansion(steps: [String], spices: [RecipeSpice]) -> Recipe {
        var updated = self
        updated.steps = steps
        updated.isExpanded = true
        return Recipe(
            id: id,
            title: title,
            calories: calories,
            cuisine: cuisine,
            difficulty: difficulty,
            description: description,
            servings: servings,
            ingredients: ingredients,
            spices: spices.isEmpty ? self.spices : spices,
            spices_common: spices_common,
            spices_optional: spices_optional,
            required_extra_ingredients: required_extra_ingredients,
            steps: steps,
            language: language,
            source: source,
            isExpanded: true
        )
    }
}

nonisolated struct CacheInfo: Codable, Sendable {
    let hit: Bool?
    let cached_count: Int?
    let fresh_count: Int?
}

nonisolated struct RecipeResponse: Codable, Sendable {
    let exact_match_recipes: [Recipe]
    let extra_ingredient_recipes: [Recipe]
    let _cache: CacheInfo?
}

nonisolated struct ExpandedRecipeDetail: Codable, Sendable {
    let id: String
    let steps: [String]
    let spices: [RecipeSpice]?
}

nonisolated struct ExpandResponse: Codable, Sendable {
    let recipes: [ExpandedRecipeDetail]
}
