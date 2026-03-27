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

    nonisolated enum CodingKeys: String, CodingKey {
        case name, quantity, unit
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        if let q = try? container.decode(String.self, forKey: .quantity) {
            quantity = q
        } else if let qNum = try? container.decode(Double.self, forKey: .quantity) {
            quantity = qNum.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(qNum))" : "\(qNum)"
        } else {
            quantity = ""
        }
        unit = (try? container.decode(String.self, forKey: .unit)) ?? ""
    }

    init(name: String, quantity: String, unit: String) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
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

    nonisolated enum CodingKeys: String, CodingKey {
        case id, title, calories, cuisine, difficulty, description, servings
        case ingredients, spices, spices_common, spices_optional
        case required_extra_ingredients, steps, language, source, isExpanded
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? "recipe_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 10000...99999))"
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        if let calStr = try? container.decode(String.self, forKey: .calories) {
            calories = calStr
        } else if let calInt = try? container.decode(Int.self, forKey: .calories) {
            calories = "\(calInt)"
        } else {
            calories = ""
        }
        cuisine = (try? container.decode(String.self, forKey: .cuisine)) ?? ""
        difficulty = (try? container.decode(String.self, forKey: .difficulty)) ?? ""
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        if let s = try? container.decode(Int.self, forKey: .servings) {
            servings = s
        } else if let sStr = try? container.decode(String.self, forKey: .servings), let sInt = Int(sStr) {
            servings = sInt
        } else {
            servings = 2
        }
        ingredients = (try? container.decode([RecipeIngredient].self, forKey: .ingredients)) ?? []
        spices = try? container.decode([RecipeSpice].self, forKey: .spices)
        spices_common = try? container.decode([String].self, forKey: .spices_common)
        spices_optional = try? container.decode([String].self, forKey: .spices_optional)
        required_extra_ingredients = (try? container.decode([String].self, forKey: .required_extra_ingredients)) ?? []
        steps = (try? container.decode([String].self, forKey: .steps)) ?? []
        language = try? container.decode(String.self, forKey: .language)
        source = try? container.decode(String.self, forKey: .source)
        isExpanded = try? container.decode(Bool.self, forKey: .isExpanded)
    }

    init(id: String, title: String, calories: String, cuisine: String, difficulty: String, description: String, servings: Int, ingredients: [RecipeIngredient], spices: [RecipeSpice]?, spices_common: [String]?, spices_optional: [String]?, required_extra_ingredients: [String], steps: [String], language: String?, source: String?, isExpanded: Bool?) {
        self.id = id
        self.title = title
        self.calories = calories
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.description = description
        self.servings = servings
        self.ingredients = ingredients
        self.spices = spices
        self.spices_common = spices_common
        self.spices_optional = spices_optional
        self.required_extra_ingredients = required_extra_ingredients
        self.steps = steps
        self.language = language
        self.source = source
        self.isExpanded = isExpanded
    }

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

    nonisolated enum CodingKeys: String, CodingKey {
        case exact_match_recipes
        case extra_ingredient_recipes
        case _cache
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            exact_match_recipes = try container.decodeIfPresent([Recipe].self, forKey: .exact_match_recipes) ?? []
        } catch {
            print("[RecipeResponse] Failed to decode exact_match_recipes: \(error)")
            exact_match_recipes = []
        }
        do {
            extra_ingredient_recipes = try container.decodeIfPresent([Recipe].self, forKey: .extra_ingredient_recipes) ?? []
        } catch {
            print("[RecipeResponse] Failed to decode extra_ingredient_recipes: \(error)")
            extra_ingredient_recipes = []
        }
        _cache = try? container.decode(CacheInfo.self, forKey: ._cache)
    }

    init(exact_match_recipes: [Recipe], extra_ingredient_recipes: [Recipe], _cache: CacheInfo?) {
        self.exact_match_recipes = exact_match_recipes
        self.extra_ingredient_recipes = extra_ingredient_recipes
        self._cache = _cache
    }
}

nonisolated struct ExpandedRecipeDetail: Codable, Sendable {
    let id: String
    let steps: [String]
    let spices: [RecipeSpice]
}

nonisolated struct ExpandResponse: Codable, Sendable {
    let recipes: [ExpandedRecipeDetail]
}
