import Foundation

nonisolated enum OpenAIError: Error, Sendable, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(String)
    case noAPIKey
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL"
        case .invalidResponse: return "Invalid response from server"
        case .apiError(let msg): return msg
        case .decodingError(let msg): return "Failed to parse recipes: \(msg)"
        case .noAPIKey: return "API key not configured"
        case .rateLimited: return "Too many requests. Please wait a moment."
        }
    }
}

nonisolated struct GenerateRecipeRequest: Codable, Sendable {
    let ingredients: [String]
    let cuisines: [String]
    let servings: Int
    let language: String
    let exactCount: Int
    let extraCount: Int
    let excludeTitles: [String]
    let deviceId: String
}

nonisolated struct ExpandRecipesRequest: Codable, Sendable {
    let recipes: [Recipe]
    let language: String
    let deviceId: String
}

nonisolated struct TranslateRecipesRequest: Codable, Sendable {
    let recipes: [Recipe]
    let targetLanguage: String
    let deviceId: String
}

nonisolated struct BackendErrorResponse: Codable, Sendable {
    let error: String
}

// ─────────────────────────────────────────────────────────────────────────────
class OpenAIService {
    static let shared = OpenAIService()

    private var backendBaseURL: String {
        let url = Config.EXPO_PUBLIC_RORK_API_BASE_URL
        guard !url.isEmpty else { return "" }
        return url + "/api"
    }

    private var deviceId: String {
        KeychainHelper.persistentDeviceId
    }

    private var isBackendConfigured: Bool {
        !backendBaseURL.isEmpty
    }

    // ── Phase 1: Preview ─────────────────────────────────────────────────────
    // Fast (~5-8s). Returns title, description, ingredients only.
    // steps and spices are empty — filled later by expandRecipes.
    func generatePreviews(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String = "en",
        exactCount: Int = 2,
        extraCount: Int = 2,
        excludeTitles: [String] = []
    ) async throws -> RecipeResponse {
        let urlString = "\(backendBaseURL)/generate-recipe-previews"
        guard let url = URL(string: urlString) else { throw OpenAIError.invalidURL }

        let requestBody = GenerateRecipeRequest(
            ingredients: ingredients,
            cuisines: cuisines,
            servings: servings,
            language: language,
            exactCount: exactCount,
            extraCount: extraCount,
            excludeTitles: excludeTitles,
            deviceId: deviceId
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        if httpResponse.statusCode == 429 { throw OpenAIError.rateLimited }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Backend error (\(httpResponse.statusCode))")
        }
        return try JSONDecoder().decode(RecipeResponse.self, from: data)
    }

    // ── Phase 2: Expand ───────────────────────────────────────────────────────
    // Takes 1 recipe at a time, returns steps + spices.
    func expandRecipes(_ recipes: [Recipe], language: String) async throws -> [ExpandedRecipeDetail] {
        let urlString = "\(backendBaseURL)/expand-recipes"
        guard let url = URL(string: urlString) else { throw OpenAIError.invalidURL }

        let requestBody = ExpandRecipesRequest(
            recipes: recipes,
            language: language,
            deviceId: deviceId
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 90
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Expand error (\(httpResponse.statusCode))")
        }
        return try JSONDecoder().decode(ExpandResponse.self, from: data).recipes
    }

    // ── Translation ───────────────────────────────────────────────────────────
    func translateRecipes(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        if isBackendConfigured {
            do {
                return try await translateViaBackend(recipes, to: language)
            } catch {
                // Fall through to direct translation if backend fails
                if !Config.EXPO_PUBLIC_OPENAI_API_KEY.isEmpty {
                    return try await translateDirectly(recipes, to: language)
                }
                throw error
            }
        }
        return try await translateDirectly(recipes, to: language)
    }

    private func translateViaBackend(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        let urlString = "\(backendBaseURL)/translate-recipes"
        guard let url = URL(string: urlString) else { throw OpenAIError.invalidURL }

        let requestBody = TranslateRecipesRequest(
            recipes: recipes,
            targetLanguage: language,
            deviceId: deviceId
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        if httpResponse.statusCode == 429 { throw OpenAIError.rateLimited }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Translation error (\(httpResponse.statusCode))")
        }
        do {
            return try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            throw OpenAIError.decodingError(error.localizedDescription)
        }
    }

    private func translateDirectly(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        let apiKey = Config.EXPO_PUBLIC_OPENAI_API_KEY
        guard !apiKey.isEmpty else { throw OpenAIError.noAPIKey }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { throw OpenAIError.invalidURL }

        let recipesJSON = try JSONEncoder().encode(recipes)
        let recipesString = String(data: recipesJSON, encoding: .utf8) ?? "[]"
        let targetLang = language == "tr" ? "Turkish" : "English"

        let systemPrompt = """
        You are a translator. Translate the given recipe JSON array into \(targetLang).
        Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, units, steps, required_extra_ingredients.
        For "spices": translate each spice "name" and "alternatives".
        Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
        For difficulty use: \(language == "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard")
        Respond with ONLY the translated JSON array. No markdown, no extra text.
        """

        let request = OpenAIChatRequest(
            model: "gpt-4o-mini",
            response_format: nil,
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: recipesString)
            ],
            temperature: 0.3,
            max_tokens: 8000
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("Translation failed: \(body)")
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert translation to data")
        }
        return try JSONDecoder().decode([Recipe].self, from: jsonData)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
nonisolated struct OpenAIChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

nonisolated struct OpenAIResponseFormat: Codable, Sendable {
    let type: String
}

nonisolated struct OpenAIChatRequest: Codable, Sendable {
    let model: String
    let response_format: OpenAIResponseFormat?
    let messages: [OpenAIChatMessage]
    let temperature: Double
    let max_tokens: Int
}

nonisolated struct OpenAIChatChoice: Codable, Sendable {
    let message: OpenAIChatMessage
}

nonisolated struct OpenAIChatResponse: Codable, Sendable {
    let choices: [OpenAIChatChoice]
}
