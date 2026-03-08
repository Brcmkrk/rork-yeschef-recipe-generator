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

    private var backendReachable: Bool = true
    private var lastBackendCheck: Date = .distantPast
    private let backendCheckInterval: TimeInterval = 120

    private var isBackendConfigured: Bool {
        let url = Config.EXPO_PUBLIC_RORK_API_BASE_URL
        let configured = !url.isEmpty
        if configured && !backendReachable && Date().timeIntervalSince(lastBackendCheck) < backendCheckInterval {
            print("[OpenAIService] Backend URL set but recently unreachable, skipping")
            return false
        }
        print("[OpenAIService] Backend configured: \(configured), URL: '\(backendBaseURL)'")
        return configured
    }

    private var hasDirectAPIKey: Bool {
        !Config.EXPO_PUBLIC_OPENAI_API_KEY.isEmpty
    }

    private func markBackendDown() {
        backendReachable = false
        lastBackendCheck = Date()
    }

    private func markBackendUp() {
        backendReachable = true
        lastBackendCheck = Date()
    }

    private func callOpenAIDirectly(
        messages: [(role: String, content: String)],
        temperature: Double,
        maxTokens: Int,
        jsonMode: Bool = false
    ) async throws -> String {
        let apiKey = Config.EXPO_PUBLIC_OPENAI_API_KEY
        guard !apiKey.isEmpty else { throw OpenAIError.noAPIKey }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { throw OpenAIError.invalidURL }

        let chatMessages = messages.map { OpenAIChatMessage(role: $0.role, content: $0.content) }
        let request = OpenAIChatRequest(
            model: "gpt-4o-mini",
            response_format: jsonMode ? OpenAIResponseFormat(type: "json_object") : nil,
            messages: chatMessages,
            temperature: temperature,
            max_tokens: maxTokens
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        if httpResponse.statusCode == 429 { throw OpenAIError.rateLimited }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("OpenAI error (\(httpResponse.statusCode)): \(body)")
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        return content
    }

    func generatePreviews(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String = "en",
        exactCount: Int = 2,
        extraCount: Int = 2,
        excludeTitles: [String] = []
    ) async throws -> RecipeResponse {
        // Guard: need at least backend OR direct API key
        guard isBackendConfigured || hasDirectAPIKey else {
            throw OpenAIError.apiError("API ayarları eksik. Lütfen uygulamayı güncelleyin.")
        }

        if isBackendConfigured {
            do {
                let result = try await generatePreviewsViaBackend(
                    ingredients: ingredients, cuisines: cuisines, servings: servings,
                    language: language, exactCount: exactCount, extraCount: extraCount,
                    excludeTitles: excludeTitles
                )
                markBackendUp()
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[OpenAIService] Backend preview failed: \(error.localizedDescription), hasDirectKey=\(hasDirectAPIKey)")
                markBackendDown()
                if hasDirectAPIKey {
                    print("[OpenAIService] Falling back to direct OpenAI...")
                    return try await generatePreviewsDirectly(
                        ingredients: ingredients, cuisines: cuisines, servings: servings,
                        language: language, exactCount: exactCount, extraCount: extraCount,
                        excludeTitles: excludeTitles
                    )
                }
                throw error
            }
        }
        return try await generatePreviewsDirectly(
            ingredients: ingredients, cuisines: cuisines, servings: servings,
            language: language, exactCount: exactCount, extraCount: extraCount,
            excludeTitles: excludeTitles
        )
    }

    private func generatePreviewsViaBackend(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String,
        exactCount: Int,
        extraCount: Int,
        excludeTitles: [String]
    ) async throws -> RecipeResponse {
        let urlString = "\(backendBaseURL)/generate-recipe-previews"
        print("[OpenAIService] Backend URL: \(urlString)")
        guard let url = URL(string: urlString) else { throw OpenAIError.invalidURL }

        let requestBody = GenerateRecipeRequest(
            ingredients: ingredients, cuisines: cuisines, servings: servings,
            language: language, exactCount: exactCount, extraCount: extraCount,
            excludeTitles: excludeTitles, deviceId: deviceId
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            print("[OpenAIService] Backend network error: \(error.localizedDescription)")
            throw OpenAIError.apiError("Backend unreachable: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        let bodyString = String(data: data, encoding: .utf8) ?? ""
        print("[OpenAIService] Preview response (\(httpResponse.statusCode)): \(bodyString.prefix(500))")

        guard httpResponse.statusCode != 404 else {
            throw OpenAIError.apiError("Backend not deployed (404)")
        }
        if httpResponse.statusCode == 429 { throw OpenAIError.rateLimited }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Backend error (\(httpResponse.statusCode)): \(bodyString.prefix(200))")
        }

        do {
            let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)
            if decoded.exact_match_recipes.isEmpty && decoded.extra_ingredient_recipes.isEmpty {
                print("[OpenAIService] Backend returned empty recipe arrays. Response: \(bodyString.prefix(1000))")
            }
            return decoded
        } catch {
            print("[OpenAIService] Backend decode error: \(error)")
            print("[OpenAIService] Backend response body: \(bodyString.prefix(1000))")
            throw OpenAIError.apiError("Server returned invalid data. Please try again.")
        }
    }

    private func generatePreviewsDirectly(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String,
        exactCount: Int,
        extraCount: Int,
        excludeTitles: [String]
    ) async throws -> RecipeResponse {
        let isTurkish = language == "tr"
        let bannedList: String
        if !excludeTitles.isEmpty {
            let items = excludeTitles.map { "  * \($0)" }.joined(separator: "\n")
            bannedList = isTurkish
                ? "\n- YASAK: Şu tarifleri TEKRAR VERME:\n\(items)"
                : "\n- BANNED: Do NOT generate any of these recipes:\n\(items)"
        } else {
            bannedList = ""
        }

        let systemPrompt: String
        if isTurkish {
            systemPrompt = """
            Sen profesyonel bir şef ve tarif oluşturucusun. SADECE geçerli JSON döndür.

            BU BİR ÖNİZLEME İSTEĞİDİR — "steps" ve "spices" alanları EKLEME.

            Döndürmen gereken JSON yapısı:
            {
              "exact_match_recipes": [
                {
                  "id": "benzersiz_string",
                  "title": "Tarif Adı",
                  "calories": "300-400",
                  "cuisine": "İtalyan",
                  "difficulty": "Kolay|Orta|Zor",
                  "description": "1-2 cümlelik kısa açıklama",
                  "servings": 2,
                  "ingredients": [{"name": "tavuk", "quantity": "500", "unit": "g"}],
                  "required_extra_ingredients": []
                }
              ],
              "extra_ingredient_recipes": [aynı yapı]
            }

            Kurallar:
            - Tam olarak \(exactCount) exact_match_recipes ve \(extraCount) extra_ingredient_recipes döndür
            - exact_match_recipes: sadece kullanıcının malzemeleri + temel mutfak malzemeleri. required_extra_ingredients = []
            - extra_ingredient_recipes: kullanıcı malzemeleri + required_extra_ingredients'te 2-4 ek malzeme
            - HER ZAMAN tarif oluştur. Malzemeler ne olursa olsun yaratıcı ol ve bir tarif bul. ASLA boş dizi döndürme.
            - HER ŞEY TÜRKÇE OLMALI\(bannedList)
            """
        } else {
            systemPrompt = """
            You are a professional chef. Respond with ONLY valid JSON.

            THIS IS A PREVIEW REQUEST — Do NOT include "steps" or "spices" fields.

            Return this JSON structure:
            {
              "exact_match_recipes": [
                {
                  "id": "unique_string",
                  "title": "Recipe Name",
                  "calories": "300-400",
                  "cuisine": "Italian",
                  "difficulty": "Easy|Medium|Hard",
                  "description": "Short 1-2 sentence description",
                  "servings": 2,
                  "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
                  "required_extra_ingredients": []
                }
              ],
              "extra_ingredient_recipes": [same structure]
            }

            Rules:
            - Return exactly \(exactCount) exact_match_recipes and \(extraCount) extra_ingredient_recipes
            - exact_match_recipes: use only user's ingredients + basic pantry items. required_extra_ingredients = []
            - extra_ingredient_recipes: user ingredients + 2-4 extra ingredients in required_extra_ingredients
            - ALWAYS generate recipes no matter what ingredients are given. Be creative. NEVER return empty arrays.
            - All content in English\(bannedList)
            """
        }

        let ingredientList = ingredients.joined(separator: ", ")
        let cuisineList = cuisines.isEmpty ? (isTurkish ? "Herhangi bir mutfak" : "Any cuisine") : cuisines.joined(separator: ", ")

        var excludeNote = ""
        if !excludeTitles.isEmpty {
            let titles = excludeTitles.joined(separator: ", ")
            excludeNote = isTurkish
                ? "\n\nÖNEMLİ: Şu tarifleri TEKRAR VERME: \(titles)"
                : "\n\nIMPORTANT: Do NOT repeat these recipes: \(titles)"
        }

        let totalCount = exactCount + extraCount
        let userPrompt: String
        if isTurkish {
            userPrompt = "Bu malzemeleri kullanarak \(totalCount) tarif oluştur: \(ingredientList)\n\nMutfak tercihleri: \(cuisineList)\nPorsiyon: \(servings)\n\nSADECE geçerli JSON döndür. HER ŞEY TÜRKÇE OLMALI.\(excludeNote)"
        } else {
            userPrompt = "Generate \(totalCount) recipes using these ingredients: \(ingredientList)\n\nCuisine preferences: \(cuisineList)\nServings: \(servings)\n\nReturn ONLY valid JSON. All content in English.\(excludeNote)"
        }

        let content = try await callOpenAIDirectly(
            messages: [
                (role: "system", content: systemPrompt),
                (role: "user", content: userPrompt)
            ],
            temperature: 0.85,
            maxTokens: 5500,
            jsonMode: true
        )

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert to data")
        }

        let parsed: DirectPreviewResponse
        do {
            parsed = try JSONDecoder().decode(DirectPreviewResponse.self, from: jsonData)
        } catch {
            print("[OpenAIService] Direct preview decode error: \(error)")
            print("[OpenAIService] Raw JSON (first 1000): \(cleaned.prefix(1000))")
            if let wrapper = try? JSONDecoder().decode(WrappedPreviewResponse.self, from: jsonData) {
                let exactRaw = wrapper.recipes?.prefix(exactCount) ?? []
                let extraRaw = wrapper.recipes?.dropFirst(exactCount).prefix(extraCount) ?? []
                let exactRecipes = exactRaw.map { toRecipe($0) }
                let extraRecipes = extraRaw.map { toRecipe($0) }
                return RecipeResponse(
                    exact_match_recipes: Array(exactRecipes),
                    extra_ingredient_recipes: Array(extraRecipes),
                    _cache: nil
                )
            }
            throw OpenAIError.apiError("Tarif oluşturulamadı, lütfen tekrar deneyin.")
        }

        func toRecipe(_ r: RawRecipe) -> Recipe {
            Recipe(
                id: r.id ?? "recipe_\(Int(Date().timeIntervalSince1970))_\(String(Int.random(in: 10000...99999)))",
                title: r.title ?? "",
                calories: r.calories ?? "",
                cuisine: r.cuisine ?? "",
                difficulty: r.difficulty ?? "",
                description: r.description ?? "",
                servings: r.servings ?? servings,
                ingredients: (r.ingredients ?? []).map {
                    RecipeIngredient(name: $0.name ?? "", quantity: $0.quantity ?? "", unit: $0.unit ?? "")
                },
                spices: nil,
                spices_common: nil,
                spices_optional: nil,
                required_extra_ingredients: r.required_extra_ingredients ?? [],
                steps: [],
                language: language,
                source: "generated",
                isExpanded: false
            )
        }

        let exactRecipes = (parsed.exact_match_recipes ?? []).prefix(exactCount).map { toRecipe($0) }
        let extraRecipes = (parsed.extra_ingredient_recipes ?? []).prefix(extraCount).map { toRecipe($0) }

        return RecipeResponse(
            exact_match_recipes: Array(exactRecipes),
            extra_ingredient_recipes: Array(extraRecipes),
            _cache: nil
        )
    }

    func expandRecipes(_ recipes: [Recipe], language: String) async throws -> [ExpandedRecipeDetail] {
        if isBackendConfigured {
            do {
                let result = try await expandRecipesViaBackend(recipes, language: language)
                markBackendUp()
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[OpenAIService] Backend expand failed: \(error.localizedDescription), trying direct...")
                markBackendDown()
                if hasDirectAPIKey {
                    return try await expandRecipesDirectly(recipes, language: language)
                }
                throw error
            }
        }
        return try await expandRecipesDirectly(recipes, language: language)
    }

    private func expandRecipesViaBackend(_ recipes: [Recipe], language: String) async throws -> [ExpandedRecipeDetail] {
        let urlString = "\(backendBaseURL)/expand-recipes"
        guard let url = URL(string: urlString) else { throw OpenAIError.invalidURL }

        let requestBody = ExpandRecipesRequest(recipes: recipes, language: language, deviceId: deviceId)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            print("[OpenAIService] Expand network error: \(error.localizedDescription)")
            throw OpenAIError.apiError("Backend unreachable: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        let bodyString = String(data: data, encoding: .utf8) ?? ""
        print("[OpenAIService] Expand response (\(httpResponse.statusCode)): \(bodyString.prefix(500))")

        guard httpResponse.statusCode != 404 else {
            throw OpenAIError.apiError("Backend not deployed (404)")
        }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Expand error (\(httpResponse.statusCode)): \(bodyString.prefix(200))")
        }

        do {
            return try JSONDecoder().decode(ExpandResponse.self, from: data).recipes
        } catch {
            print("[OpenAIService] Expand decode error: \(error)")
            throw OpenAIError.apiError("Failed to parse recipe details. Please try again.")
        }
    }

    private func expandRecipesDirectly(_ recipes: [Recipe], language: String) async throws -> [ExpandedRecipeDetail] {
        let isTurkish = language == "tr"
        let systemPrompt: String
        if isTurkish {
            systemPrompt = """
            Sen profesyonel bir şefsin. Sana tarif önizlemeleri verilecek. Her tarif için detaylı adımlar ve baharatlar oluştur.

            SADECE geçerli JSON döndür.

            Döndürmen gereken yapı:
            {
              "recipes": [
                {
                  "id": "orijinal_tarif_id",
                  "steps": ["Adım 1...", "Adım 2..."],
                  "spices": [
                    {"name": "tuz", "alternatives": ["deniz tuzu", "himalaya tuzu"]}
                  ]
                }
              ]
            }

            Kurallar:
            - Her tarifin 5-8 detaylı adımı olsun
            - Her adımda kesin süre, sıcaklık ve görsel ipuçları ver
            - spices dizisinde kullanılan TÜM baharatları listele, her birinin 2-3 alternatifi olsun
            - HER ŞEY TÜRKÇE OLMALI
            """
        } else {
            systemPrompt = """
            You are a professional chef. Generate detailed steps and spices for each recipe.

            Respond with ONLY valid JSON.

            Return this structure:
            {
              "recipes": [
                {
                  "id": "original_recipe_id",
                  "steps": ["Step 1...", "Step 2..."],
                  "spices": [
                    {"name": "salt", "alternatives": ["sea salt", "pink salt"]}
                  ]
                }
              ]
            }

            Rules:
            - Each recipe must have 5-8 clear, detailed steps
            - Every step must include precise timing, temperature, and visual cues
            - List ALL spices used with 2-3 alternatives each
            - All content in English
            """
        }

        let summaries = recipes.map { r in
            [
                "id": r.id,
                "title": r.title,
                "ingredients": r.ingredients.map { $0.name }.joined(separator: ", "),
                "required_extra_ingredients": r.required_extra_ingredients.joined(separator: ", "),
                "servings": "\(r.servings)"
            ]
        }

        guard let summaryData = try? JSONSerialization.data(withJSONObject: summaries),
              let summaryString = String(data: summaryData, encoding: .utf8) else {
            throw OpenAIError.decodingError("Could not serialize recipe summaries")
        }

        let userPrompt = isTurkish
            ? "Şu tarifler için detaylı adımlar ve baharatlar oluştur:\n\(summaryString)\n\nSADECE geçerli JSON döndür. HER ŞEY TÜRKÇE."
            : "Generate detailed steps and spices for these recipes:\n\(summaryString)\n\nReturn ONLY valid JSON. All content in English."

        let content = try await callOpenAIDirectly(
            messages: [
                (role: "system", content: systemPrompt),
                (role: "user", content: userPrompt)
            ],
            temperature: 0.75,
            maxTokens: 4000,
            jsonMode: true
        )

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert expand response to data")
        }

        do {
            return try JSONDecoder().decode(ExpandResponse.self, from: jsonData).recipes
        } catch {
            print("[OpenAIService] Direct expand decode error: \(error)")
            throw OpenAIError.apiError("Failed to parse recipe details. Please try again.")
        }
    }

    func translateRecipes(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        if isBackendConfigured {
            do {
                let result = try await translateViaBackend(recipes, to: language)
                markBackendUp()
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[OpenAIService] Backend translate failed: \(error.localizedDescription), trying direct...")
                markBackendDown()
                if hasDirectAPIKey {
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

        let requestBody = TranslateRecipesRequest(recipes: recipes, targetLanguage: language, deviceId: deviceId)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            print("[OpenAIService] Translate network error: \(error.localizedDescription)")
            throw OpenAIError.apiError("Backend unreachable: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        let bodyString = String(data: data, encoding: .utf8) ?? ""
        print("[OpenAIService] Translate response (\(httpResponse.statusCode)): \(bodyString.prefix(500))")

        guard httpResponse.statusCode != 404 else {
            throw OpenAIError.apiError("Backend not deployed (404)")
        }
        if httpResponse.statusCode == 429 { throw OpenAIError.rateLimited }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            throw OpenAIError.apiError("Translation error (\(httpResponse.statusCode)): \(bodyString.prefix(200))")
        }
        do {
            return try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            print("[OpenAIService] Translate decode error: \(error)")
            throw OpenAIError.apiError("Failed to parse translation. Please try again.")
        }
    }

    private func translateDirectly(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        let targetLang = language == "tr" ? "Turkish" : "English"

        let systemPrompt = """
        You are a translator. Translate the given recipe JSON array into \(targetLang).
        Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, units, steps, required_extra_ingredients.
        For "spices": translate each spice "name" and "alternatives".
        Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
        For difficulty use: \(language == "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard")
        Respond with ONLY the translated JSON array. No markdown, no extra text.
        """

        let recipesJSON = try JSONEncoder().encode(recipes)
        let recipesString = String(data: recipesJSON, encoding: .utf8) ?? "[]"

        let content = try await callOpenAIDirectly(
            messages: [
                (role: "system", content: systemPrompt),
                (role: "user", content: recipesString)
            ],
            temperature: 0.3,
            maxTokens: 8000,
            jsonMode: false
        )

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert translation to data")
        }
        do {
            return try JSONDecoder().decode([Recipe].self, from: jsonData)
        } catch {
            print("[OpenAIService] Direct translate decode error: \(error)")
            throw OpenAIError.apiError("Failed to parse translation. Please try again.")
        }
    }
}

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

// ── Private helper structs for generatePreviewsDirectly ──────────────────────
nonisolated struct DirectPreviewResponse: Codable, Sendable {
    let exact_match_recipes: [RawRecipe]?
    let extra_ingredient_recipes: [RawRecipe]?
}

nonisolated struct WrappedPreviewResponse: Codable, Sendable {
    let recipes: [RawRecipe]?
}

nonisolated struct RawRecipe: Codable, Sendable {
    let id: String?
    let title: String?
    let description: String?
    let calories: String?
    let cuisine: String?
    let difficulty: String?
    let servings: Int?
    let ingredients: [RawIngredient]?
    let required_extra_ingredients: [String]?
}

nonisolated struct RawIngredient: Codable, Sendable {
    let name: String?
    let quantity: String?
    let unit: String?
}

