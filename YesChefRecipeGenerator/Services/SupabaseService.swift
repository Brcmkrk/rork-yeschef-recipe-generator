import Foundation

nonisolated enum FlexibleID: Codable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .int(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

nonisolated struct SupabaseCacheRow: Codable, Sendable {
    let id: FlexibleID
    let recipe_id: String
    let recipe_data: RecipeData
    let created_at: String?
}

nonisolated struct SupabaseReaction: Codable, Sendable {
    let id: Int?
    let device_id: String
    let recipe_id: String
    let recipe_data: RecipeData
    let reaction: String
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseTriedRecipe: Codable, Sendable {
    let id: Int?
    let device_id: String
    let recipe_id: String
    let recipe_data: RecipeData
    let created_at: String?
    let updated_at: String?
}

nonisolated enum RecipeData: Codable, Sendable {
    case string(String)
    case object(Recipe)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let recipe = try? container.decode(Recipe.self) {
            self = .object(recipe)
        } else {
            self = .string("{}")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .object(let recipe):
            try container.encode(recipe)
        }
    }

    func toRecipe() -> Recipe? {
        switch self {
        case .string(let str):
            guard let data = str.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Recipe.self, from: data)
        case .object(let recipe):
            return recipe
        }
    }
}

nonisolated struct RecipeCounts: Sendable {
    var likes: Int = 0
    var dislikes: Int = 0
}

nonisolated struct ReactionRow: Codable, Sendable {
    let recipe_id: String
    let reaction: String
}

class SupabaseService {
    static let shared = SupabaseService()

    private var baseURL: String {
        Config.EXPO_PUBLIC_SUPABASE_URL
    }

    private var apiKey: String {
        Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
    }

    private var deviceId: String {
        KeychainHelper.persistentDeviceId
    }

    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    private func makeRequest(path: String, method: String, body: Data? = nil, queryParams: String = "") -> URLRequest? {
        let urlString = "\(baseURL)/rest/v1/\(path)\(queryParams.isEmpty ? "" : "?\(queryParams)")"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method == "POST" || method == "PATCH" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        return request
    }

    private func encodeRecipeForDB(_ recipe: Recipe) -> Any {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(recipe),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return [String: Any]()
        }
        return obj
    }

    func fetchMyReactions() async throws -> [SupabaseReaction] {
        guard isConfigured else { return [] }
        let query = "select=*&device_id=eq.\(deviceId)&order=created_at.desc"
        guard let request = makeRequest(path: "recipe_reactions", method: "GET", queryParams: query) else { return [] }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([SupabaseReaction].self, from: data)) ?? []
    }

    func upsertReaction(recipeId: String, recipe: Recipe, reaction: String) async throws {
        guard isConfigured else { return }

        let recipeObj = encodeRecipeForDB(recipe)

        let existing = try await fetchReaction(recipeId: recipeId)

        if let existing = existing, let existingId = existing.id {
            let query = "id=eq.\(existingId)"
            let body: [String: Any] = ["reaction": reaction, "recipe_data": recipeObj]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest(path: "recipe_reactions", method: "PATCH", body: bodyData, queryParams: query) else { return }
            _ = try await URLSession.shared.data(for: request)
        } else {
            let body: [String: Any] = [
                "device_id": deviceId,
                "recipe_id": recipeId,
                "recipe_data": recipeObj,
                "reaction": reaction
            ]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest(path: "recipe_reactions", method: "POST", body: bodyData) else { return }
            _ = try await URLSession.shared.data(for: request)
        }
    }

    func deleteReaction(recipeId: String) async throws {
        guard isConfigured else { return }
        let query = "device_id=eq.\(deviceId)&recipe_id=eq.\(recipeId)"
        guard let request = makeRequest(path: "recipe_reactions", method: "DELETE", queryParams: query) else { return }
        _ = try await URLSession.shared.data(for: request)
    }

    func fetchGlobalCounts(recipeIds: [String]) async -> [String: RecipeCounts] {
        guard isConfigured, !recipeIds.isEmpty else { return [:] }
        let idFilter = recipeIds.map { "\"\($0)\"" }.joined(separator: ",")
        let query = "select=recipe_id,reaction&recipe_id=in.(\(idFilter))"
        guard let request = makeRequest(path: "recipe_reactions", method: "GET", queryParams: query) else { return [:] }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [:] }
            let rows = (try? JSONDecoder().decode([ReactionRow].self, from: data)) ?? []

            var counts: [String: RecipeCounts] = [:]
            for row in rows {
                var c = counts[row.recipe_id] ?? RecipeCounts()
                if row.reaction == "like" {
                    c.likes += 1
                } else if row.reaction == "dislike" {
                    c.dislikes += 1
                }
                counts[row.recipe_id] = c
            }
            return counts
        } catch {
            return [:]
        }
    }

    private func fetchReaction(recipeId: String) async throws -> SupabaseReaction? {
        guard isConfigured else { return nil }
        let query = "select=*&device_id=eq.\(deviceId)&recipe_id=eq.\(recipeId)&limit=1"
        guard let request = makeRequest(path: "recipe_reactions", method: "GET", queryParams: query) else { return nil }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let results = (try? JSONDecoder().decode([SupabaseReaction].self, from: data)) ?? []
        return results.first
    }

    func fetchMyTriedRecipes() async throws -> [SupabaseTriedRecipe] {
        guard isConfigured else { return [] }
        let query = "select=*&device_id=eq.\(deviceId)&order=created_at.desc"
        guard let request = makeRequest(path: "tried_recipes", method: "GET", queryParams: query) else { return [] }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([SupabaseTriedRecipe].self, from: data)) ?? []
    }

    func upsertTriedRecipe(recipe: Recipe) async throws {
        guard isConfigured else { return }

        let recipeObj = encodeRecipeForDB(recipe)

        let existing = try? await fetchTriedRecipe(recipeId: recipe.id)
        if existing != nil {
            let body: [String: Any] = ["recipe_data": recipeObj]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
            let query = "device_id=eq.\(deviceId)&recipe_id=eq.\(recipe.id)"
            guard let request = makeRequest(path: "tried_recipes", method: "PATCH", body: bodyData, queryParams: query) else { return }
            _ = try await URLSession.shared.data(for: request)
            return
        }

        let body: [String: Any] = [
            "device_id": deviceId,
            "recipe_id": recipe.id,
            "recipe_data": recipeObj
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        guard let request = makeRequest(path: "tried_recipes", method: "POST", body: bodyData) else { return }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let respBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("[SupabaseService] tried_recipes POST failed: \(http.statusCode) - \(respBody)")
        }
    }

    func deleteTriedRecipe(recipeId: String) async throws {
        guard isConfigured else { return }
        let query = "device_id=eq.\(deviceId)&recipe_id=eq.\(recipeId)"
        guard let request = makeRequest(path: "tried_recipes", method: "DELETE", queryParams: query) else { return }
        _ = try await URLSession.shared.data(for: request)
    }

    private func fetchTriedRecipe(recipeId: String) async throws -> SupabaseTriedRecipe? {
        guard isConfigured else { return nil }
        let query = "select=*&device_id=eq.\(deviceId)&recipe_id=eq.\(recipeId)&limit=1"
        guard let request = makeRequest(path: "tried_recipes", method: "GET", queryParams: query) else { return nil }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let results = (try? JSONDecoder().decode([SupabaseTriedRecipe].self, from: data)) ?? []
        return results.first
    }

    private func cacheTableName(for language: String) -> String {
        language == "tr" ? "ai_cache_turkish" : "ai_cache"
    }

    private static let cuisineAliases: [String: [String]] = [
        "turkish": ["türk", "turkish"],
        "türk": ["turkish", "türk"],
        "italian": ["italian", "italyan", "İtalyan"],
        "italyan": ["italian", "italyan"],
        "mexican": ["mexican", "meksika"],
        "meksika": ["mexican", "meksika"],
        "asian": ["asian", "asya", "chinese", "korean"],
        "asya": ["asian", "asya"],
        "french": ["french", "fransız"],
        "fransız": ["french", "fransız"],
        "mediterranean": ["mediterranean", "akdeniz", "greek", "spanish"],
        "akdeniz": ["mediterranean", "akdeniz", "greek", "spanish"],
        "greek": ["greek", "mediterranean", "akdeniz"],
        "spanish": ["spanish", "mediterranean", "akdeniz"],
        "american": ["american", "amerikan"],
        "amerikan": ["american", "amerikan"],
        "indian": ["indian", "hint"],
        "hint": ["indian", "hint"],
        "japanese": ["japanese", "japon"],
        "japon": ["japanese", "japon"],
        "thai": ["thai", "asian", "asya"]
    ]

    private func cuisineMatches(_ recipeCuisine: String, selected: Set<String>) -> Bool {
        if selected.isEmpty { return true }
        let rc = recipeCuisine.lowercased()
        if selected.contains(rc) { return true }
        let aliases = Self.cuisineAliases[rc] ?? []
        for alias in aliases {
            if selected.contains(alias) { return true }
        }
        for s in selected {
            let reverseAliases = Self.cuisineAliases[s] ?? []
            if reverseAliases.contains(rc) { return true }
        }
        return false
    }

    private func stemWord(_ word: String) -> String {
        var w = word
        let suffixes = ["ler", "lar", "es", "s", "ies", "ed", "ing", "ları", "leri"]
        for suffix in suffixes {
            if w.count > suffix.count + 2 && w.hasSuffix(suffix) {
                w = String(w.dropLast(suffix.count))
                break
            }
        }
        return w
    }

    private func ingredientMatchScore(inputWord: String, recipeNames: [String], recipeText: String) -> Bool {
        let word = inputWord.lowercased().trimmingCharacters(in: .whitespaces)
        guard word.count >= 2 else { return false }
        let stemmed = stemWord(word)

        if recipeText.contains(word) { return true }
        if stemmed.count >= 3 && recipeText.contains(stemmed) { return true }

        for name in recipeNames {
            if name.contains(word) || word.contains(name) { return true }
            let nameStemmed = stemWord(name)
            if stemmed.count >= 3 && nameStemmed.count >= 3 {
                if nameStemmed.contains(stemmed) || stemmed.contains(nameStemmed) { return true }
            }
        }
        return false
    }

    func fetchCachedRecipes(ingredients: [String], servings: Int, cuisines: [String], language: String = "en") async -> [Recipe] {
        guard isConfigured else {
            print("[SupabaseService] fetchCachedRecipes: not configured")
            return []
        }

        let table = cacheTableName(for: language)
        let query = "select=id,recipe_id,recipe_data,created_at&order=created_at.desc&limit=500"
        guard let request = makeRequest(path: table, method: "GET", queryParams: query) else {
            print("[SupabaseService] fetchCachedRecipes: failed to create request for \(table)")
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                print("[SupabaseService] fetchCachedRecipes: HTTP \(status) from \(table) - \(body.prefix(200))")
                return []
            }

            let decoder = JSONDecoder()
            var rows: [SupabaseCacheRow] = []
            if let decoded = try? decoder.decode([SupabaseCacheRow].self, from: data) {
                rows = decoded
            } else {
                let rawBody = String(data: data, encoding: .utf8) ?? "empty"
                print("[SupabaseService] fetchCachedRecipes: DECODE FAILED for \(table). First 300 chars: \(rawBody.prefix(300))")
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("[SupabaseService] fetchCachedRecipes: raw JSON has \(jsonArray.count) items, first keys: \(jsonArray.first?.keys.sorted() ?? [])")
                    for item in jsonArray {
                        guard let recipeDataRaw = item["recipe_data"],
                              let recipeJSON = try? JSONSerialization.data(withJSONObject: recipeDataRaw),
                              let recipeData = try? decoder.decode(RecipeData.self, from: recipeJSON) else { continue }
                        let recipeId = (item["recipe_id"] as? String) ?? "unknown"
                        rows.append(SupabaseCacheRow(id: .int(0), recipe_id: recipeId, recipe_data: recipeData, created_at: item["created_at"] as? String))
                    }
                    print("[SupabaseService] fetchCachedRecipes: manual parse recovered \(rows.count) rows")
                }
            }

            guard !rows.isEmpty else {
                print("[SupabaseService] fetchCachedRecipes: 0 rows from \(table)")
                return []
            }

            let normalizedCuisines = Set(cuisines.map { $0.lowercased() })
            let inputWords: [String] = ingredients.flatMap { ing -> [String] in
                let lowered = ing.lowercased().trimmingCharacters(in: .whitespaces)
                var words = [lowered]
                words.append(contentsOf: lowered.split(separator: " ").map { String($0) })
                return words
            }
            let uniqueInputWords = Array(Set(inputWords)).filter { $0.count >= 2 }

            print("[SupabaseService] fetchCachedRecipes: searching \(rows.count) rows with words: \(uniqueInputWords)")

            var scored: [(recipe: Recipe, score: Int)] = []

            for row in rows {
                guard let recipe = row.recipe_data.toRecipe() else { continue }

                let cuisineMatch = cuisineMatches(recipe.cuisine, selected: normalizedCuisines)

                var allNames: [String] = recipe.ingredients.map { $0.name.lowercased().trimmingCharacters(in: .whitespaces) }
                for extra in recipe.required_extra_ingredients {
                    allNames.append(extra.lowercased().trimmingCharacters(in: .whitespaces))
                }
                let recipeText = (allNames + [recipe.title.lowercased(), recipe.description.lowercased()]).joined(separator: " ")

                var matchCount = 0
                for word in uniqueInputWords {
                    if ingredientMatchScore(inputWord: word, recipeNames: allNames, recipeText: recipeText) {
                        matchCount += 1
                    }
                }

                let rawIngredientCount = ingredients.count
                let threshold = rawIngredientCount <= 2 ? 1 : max(1, Int(ceil(Double(rawIngredientCount) * 0.2)))
                guard matchCount >= threshold else { continue }

                var score = matchCount * 10
                if cuisineMatch { score += 5 }
                if recipe.servings == servings { score += 3 }

                scored.append((recipe: recipe, score: score))
            }

            scored.sort { $0.score > $1.score }
            print("[SupabaseService] fetchCachedRecipes: \(scored.count) matches from \(rows.count) rows in \(table) (input: \(ingredients), cuisines: \(cuisines))")
            return scored.prefix(15).map {
                var r = $0.recipe
                r.source = "cache"
                return r
            }
        } catch {
            print("[SupabaseService] fetchCachedRecipes error: \(error)")
            return []
        }
    }

    func saveSearchedIngredientsWithTime(_ ingredients: [String], language: String, generationTimeMs: Int, servings: Int, cuisineCount: Int, exactMatchCount: Int, extraMatchCount: Int, cuisines: [String]) async {
        guard isConfigured, !ingredients.isEmpty else { return }

        let body: [String: Any] = [
            "device_id": deviceId,
            "ingredients": ingredients,
            "language": language,
            "generation_time_ms": generationTimeMs,
            "servings": servings,
            "cuisine_count": cuisineCount,
            "exact_match_count": exactMatchCount,
            "extra_match_count": extraMatchCount,
            "cuisines": cuisines
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let request = makeRequest(path: "searched_ingredients", method: "POST", body: bodyData) else {
            print("[SupabaseService] searched_ingredients: failed to create request")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let respBody = String(data: data, encoding: .utf8) ?? "unknown"
                print("[SupabaseService] searched_ingredients POST status: \(http.statusCode) - \(respBody.prefix(300))")
            }
        } catch {
            print("[SupabaseService] searched_ingredients error: \(error.localizedDescription)")
        }
    }

    func saveRecipesToCache(_ recipes: [Recipe], language: String = "en") async {
        guard isConfigured, !recipes.isEmpty else {
            print("[SupabaseService] saveRecipesToCache skipped: configured=\(isConfigured), count=\(recipes.count)")
            return
        }

        let table = cacheTableName(for: language)
        print("[SupabaseService] saveRecipesToCache: \(recipes.count) recipes -> table=\(table), lang=\(language)")

        for recipe in recipes {
            let recipeId = "cache_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
            let recipeObj = encodeRecipeForDB(recipe)

            var recipeDict = (recipeObj as? [String: Any]) ?? [:]
            recipeDict["id"] = recipeId

            let body: [String: Any] = [
                "recipe_id": recipeId,
                "recipe_data": recipeDict
            ]

            guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
                  let request = makeRequest(path: table, method: "POST", body: bodyData) else {
                print("[SupabaseService] \(table) POST: failed to create request")
                continue
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    let respBody = String(data: data, encoding: .utf8) ?? "unknown"
                    print("[SupabaseService] \(table) POST failed: \(http.statusCode) - \(respBody)")
                } else {
                    print("[SupabaseService] \(table) saved: \(recipe.title)")
                }
            } catch {
                print("[SupabaseService] \(table) error: \(error.localizedDescription)")
            }
        }
    }
}
