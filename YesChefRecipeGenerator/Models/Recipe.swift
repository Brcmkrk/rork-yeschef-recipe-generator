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
    let steps: [String]
    var language: String?

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
}

nonisolated struct CacheInfo: Codable, Sendable {
    let hit: Bool?
    let cached_count: Int?
}

nonisolated struct RecipeResponse: Codable, Sendable {
    let exact_match_recipes: [Recipe]
    let extra_ingredient_recipes: [Recipe]
    let _cache: CacheInfo?
}
