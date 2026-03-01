import Foundation

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
    let spices_common: [String]
    let spices_optional: [String]
    let required_extra_ingredients: [String]
    let steps: [String]
    var language: String?

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct RecipeResponse: Codable, Sendable {
    let exact_match_recipes: [Recipe]
    let extra_ingredient_recipes: [Recipe]
}
