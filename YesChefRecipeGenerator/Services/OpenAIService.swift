import Foundation

nonisolated enum OpenAIError: Error, Sendable, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL"
        case .invalidResponse: return "Invalid response from server"
        case .apiError(let msg): return msg
        case .decodingError(let msg): return "Failed to parse recipes: \(msg)"
        case .noAPIKey: return "API key not configured"
        }
    }
}

nonisolated struct OpenAIChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

nonisolated struct OpenAIChatRequest: Codable, Sendable {
    let model: String
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

class OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1/chat/completions"

    func generateRecipes(
        ingredients: [String],
        cuisines: [String],
        servings: Int
    ) async throws -> RecipeResponse {
        let apiKey = Config.EXPO_PUBLIC_OPENAI_API_KEY
        guard !apiKey.isEmpty else { throw OpenAIError.noAPIKey }
        guard let url = URL(string: baseURL) else { throw OpenAIError.invalidURL }

        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(ingredients: ingredients, cuisines: cuisines, servings: servings)

        let request = OpenAIChatRequest(
            model: "gpt-4o-mini",
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.8,
            max_tokens: 4000
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError("API returned status \(httpResponse.statusCode): \(body)")
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
            throw OpenAIError.decodingError("Could not convert response to data")
        }

        do {
            return try JSONDecoder().decode(RecipeResponse.self, from: jsonData)
        } catch {
            throw OpenAIError.decodingError(error.localizedDescription)
        }
    }

    private func buildSystemPrompt() -> String {
        """
        You are a professional chef and recipe creator. You MUST respond with ONLY valid JSON, no markdown, no extra text, no explanation.

        The JSON schema you must follow exactly:
        {
          "exact_match_recipes": [
            {
              "id": "unique_string",
              "title": "Recipe Title",
              "calories": "300-400",
              "cuisine": "Italian",
              "difficulty": "Easy|Medium|Hard",
              "description": "Short 1-2 sentence description",
              "servings": 2,
              "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
              "spices_common": ["salt", "pepper"],
              "spices_optional": ["paprika"],
              "required_extra_ingredients": [],
              "steps": ["Step 1 text", "Step 2 text"]
            }
          ],
          "extra_ingredient_recipes": [same structure]
        }

        Rules:
        - Return exactly 4 exact_match_recipes and 4 extra_ingredient_recipes
        - exact_match_recipes use ONLY the user's ingredients plus basic pantry items (water, salt, pepper, oil, butter)
        - extra_ingredient_recipes use the user's ingredients PLUS 2-4 additional ingredients listed in required_extra_ingredients
        - Scale all quantities to the requested servings
        - Include time durations in steps (e.g. "Cook for 5 minutes", "Bake for 20 minutes")
        - Make recipes realistic, diverse, and cookable
        - No duplicate or near-duplicate recipes
        - Each recipe must have 4-8 clear steps with beginner-friendly explanations
        - Separate spices into common (assume available) and optional (might need to buy)
        """
    }

    private func buildUserPrompt(ingredients: [String], cuisines: [String], servings: Int) -> String {
        let ingredientList = ingredients.joined(separator: ", ")
        let cuisineList = cuisines.isEmpty ? "Any cuisine" : cuisines.joined(separator: ", ")

        return """
        Generate 8 recipes using these ingredients: \(ingredientList)

        Cuisine preferences: \(cuisineList)
        Servings: \(servings)

        Remember: Return ONLY valid JSON matching the exact schema. No markdown formatting.
        """
    }
}
