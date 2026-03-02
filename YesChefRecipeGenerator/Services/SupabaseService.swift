import Foundation

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
}
