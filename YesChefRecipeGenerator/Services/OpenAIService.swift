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

    private var isBackendConfigured: Bool {
        !backendBaseURL.isEmpty
    }

    func generateRecipes(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String = "en",
        exactCount: Int = 2,
        extraCount: Int = 2,
        excludeTitles: [String] = []
    ) async throws -> RecipeResponse {
        if isBackendConfigured {
            do {
                return try await generateViaBackend(
                    ingredients: ingredients,
                    cuisines: cuisines,
                    servings: servings,
                    language: language,
                    exactCount: exactCount,
                    extraCount: extraCount,
                    excludeTitles: excludeTitles
                )
            } catch {
                if !Config.EXPO_PUBLIC_OPENAI_API_KEY.isEmpty {
                    return try await generateDirectly(
                        ingredients: ingredients,
                        cuisines: cuisines,
                        servings: servings,
                        language: language,
                        exactCount: exactCount,
                        extraCount: extraCount,
                        excludeTitles: excludeTitles
                    )
                }
                throw error
            }
        }
        return try await generateDirectly(
            ingredients: ingredients,
            cuisines: cuisines,
            servings: servings,
            language: language,
            exactCount: exactCount,
            extraCount: extraCount,
            excludeTitles: excludeTitles
        )
    }

    private func generateViaBackend(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String,
        exactCount: Int,
        extraCount: Int,
        excludeTitles: [String]
    ) async throws -> RecipeResponse {
        let urlString = "\(backendBaseURL)/generate-recipe"
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
        urlRequest.timeoutInterval = 120
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw OpenAIError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            let truncated = body.count > 200 ? String(body.prefix(200)) + "..." : body
            throw OpenAIError.apiError("Backend error (\(httpResponse.statusCode)): \(truncated)")
        }

        do {
            return try JSONDecoder().decode(RecipeResponse.self, from: data)
        } catch {
            throw OpenAIError.decodingError(error.localizedDescription)
        }
    }

    private func generateDirectly(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String,
        exactCount: Int,
        extraCount: Int,
        excludeTitles: [String]
    ) async throws -> RecipeResponse {
        let apiKey = Config.EXPO_PUBLIC_OPENAI_API_KEY
        guard !apiKey.isEmpty else { throw OpenAIError.noAPIKey }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { throw OpenAIError.invalidURL }

        let systemPrompt = buildSystemPrompt(language: language, exactCount: exactCount, extraCount: extraCount, excludeTitles: excludeTitles)
        let userPrompt = buildUserPrompt(ingredients: ingredients, cuisines: cuisines, servings: servings, language: language, totalCount: exactCount + extraCount, excludeTitles: excludeTitles)

        let request = OpenAIChatRequest(
            model: "gpt-4o-mini",
            response_format: OpenAIResponseFormat(type: "json_object"),
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.8,
            max_tokens: min(2500, max(1500, (exactCount + extraCount) * 1200))
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
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

    func translateRecipes(_ recipes: [Recipe], to language: String) async throws -> [Recipe] {
        if isBackendConfigured {
            do {
                return try await translateViaBackend(recipes, to: language)
            } catch {
                if !Config.EXPO_PUBLIC_OPENAI_API_KEY.isEmpty {
                    var allTranslated: [Recipe] = []
                    let batchSize = 2
                    for i in stride(from: 0, to: recipes.count, by: batchSize) {
                        let end = min(i + batchSize, recipes.count)
                        let batch = Array(recipes[i..<end])
                        let translated = try await translateDirectly(batch, to: language)
                        allTranslated.append(contentsOf: translated)
                    }
                    return allTranslated
                }
                throw error
            }
        }
        var allTranslated: [Recipe] = []
        let batchSize = 2
        for i in stride(from: 0, to: recipes.count, by: batchSize) {
            let end = min(i + batchSize, recipes.count)
            let batch = Array(recipes[i..<end])
            let translated = try await translateDirectly(batch, to: language)
            allTranslated.append(contentsOf: translated)
        }
        return allTranslated
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

        if httpResponse.statusCode == 429 {
            throw OpenAIError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            let truncated = body.count > 200 ? String(body.prefix(200)) + "..." : body
            throw OpenAIError.apiError("Translation error (\(httpResponse.statusCode)): \(truncated)")
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
        Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, ingredient units, steps, required_extra_ingredients.
        For the "spices" array: translate each spice "name" and all "alternatives" strings.
        If "spices" field is missing but "spices_common" and "spices_optional" exist, translate those too.
        Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
        For difficulty, use: \(language == "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard")
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
            throw OpenAIError.decodingError("Could not convert translation response to data")
        }

        return try JSONDecoder().decode([Recipe].self, from: jsonData)
    }

    private func buildSystemPrompt(language: String, exactCount: Int, extraCount: Int, excludeTitles: [String] = []) -> String {
        let isTurkish = language == "tr"

        if isTurkish {
            return """
            Sen profesyonel bir şef ve tarif oluşturucusun. SADECE geçerli JSON ile yanıt vermelisin, markdown yok, ekstra metin yok, açıklama yok.

            TÜMÜ Türkçe olmalı — tarif başlıkları, açıklamalar, malzeme adları, birim adları, baharat adları, adımlar, zorluk seviyesi, mutfak adı — HER ŞEY TÜRKÇE.

            Tam olarak uyman gereken JSON şeması:
            {
              "exact_match_recipes": [
                {
                  "id": "unique_string",
                  "title": "Tarif Başlığı",
                  "calories": "300-400",
                  "cuisine": "İtalyan",
                  "difficulty": "Kolay|Orta|Zor",
                  "description": "Kısa 1-2 cümlelik açıklama",
                  "servings": 2,
                  "ingredients": [{"name": "tavuk", "quantity": "500", "unit": "g"}],
                  "spices": [
                    {"name": "tuz", "alternatives": ["deniz tuzu", "himalaya tuzu"]},
                    {"name": "karabiber", "alternatives": ["beyaz biber", "yeşil biber"]},
                    {"name": "kimyon", "alternatives": ["kişniş", "rezene"]}
                  ],
                  "required_extra_ingredients": [],
                  "steps": [
                    "Tavuğu küçük parçalara kesin ve orta ateşte 2 yemek kaşığı zeytinyağında 8-10 dakika, her tarafı altın rengi olana kadar kavurun.",
                    "Soğanları ince ince doğrayın ve aynı tavada 3-4 dakika, şeffaflaşana kadar soteleyin."
                  ]
                }
              ],
              "extra_ingredient_recipes": [aynı yapı]
            }

            Kurallar:
            - Her tarife benzersiz ve yaratıcı bir isim ver. Sıradan veya genel isimler KULLANMA.
            - Tam olarak \(exactCount) exact_match_recipes ve \(extraCount) extra_ingredient_recipes döndür
            - exact_match_recipes SADECE kullanıcının malzemelerini ve temel mutfak malzemelerini (su, tuz, karabiber, yağ, tereyağı) kullanır. exact_match_recipes için required_extra_ingredients boş dizi [] olmalı.
            - ÖNEMLİ: extra_ingredient_recipes kullanıcının malzemelerini ARTI required_extra_ingredients'te listelenen 2-4 ek malzeme kullanır. required_extra_ingredients ASLA BOŞ OLMAMALI, her extra_ingredient tarifinde mutlaka 2-4 ek malzeme olmalı (örn: ["krema", "mantar", "parmesan"])
            - extra_ingredient_recipes'teki ek malzemeler kullanıcının vermediği yeni malzemeler olmalı
            - Tüm miktarları istenen porsiyona göre ayarla
            - ADIMLAR ÇOK DETAYLI OLMALI: Her adımda kesin süre belirt (örn. "5 dakika pişirin", "20 dakika fırınlayın", "3-4 dakika kavurun"), sıcaklık derecesi (örn. "180°C fırında", "orta ateşte"), miktar (örn. "2 yemek kaşığı yağ ekleyin"), ve görsel ipuçları (örn. "altın rengi olana kadar", "kaynamaya başlayana kadar") ver. Kısa ve belirsiz adımlar YAZMA.
            - Her tarifin 5-8 açık, detaylı adımı olsun
            - Tarifler gerçekçi, çeşitli ve yapılabilir olsun
            - Tekrar eden veya birbirine çok benzer tarifler olmasın
            - "spices" dizisinde tarifin kullandığı TÜM baharatları listele. Her baharatın 2-3 alternatifi olsun (yerine kullanılabilecek baharatlar).
            - ÖNEMLİ MALZEME TUTARLILIĞI: Adımlarda kullanılan HER malzeme mutlaka "ingredients" veya "required_extra_ingredients" listesinde yer almalı. Örneğin adımlarda "yufka açın" yazıyorsa, yufka mutlaka malzeme listesinde olmalı. Tarifi oluşturduktan sonra adımları tekrar kontrol et ve eksik malzeme varsa ekle. Baharatlar hariç hiçbir malzeme atlanmamalı.
            - HER ŞEY TÜRKÇE OLMALI — İngilizce tek bir kelime bile olmamalı
            \(excludeTitles.isEmpty ? "" : "\n- ÇOK ÖNEMLİ YASAK LİSTESİ: Aşağıdaki tarifleri KESİNLİKLE TEKRAR VERME. Bu isimlere benzer tarifler de VERME. Tamamen farklı yemek türleri ve pişirme yöntemleri kullan:\n\(excludeTitles.map { "  * \($0)" }.joined(separator: "\n"))")
            """
        } else {
            return """
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
                  "spices": [
                    {"name": "salt", "alternatives": ["sea salt", "pink salt"]},
                    {"name": "black pepper", "alternatives": ["white pepper", "green peppercorn"]},
                    {"name": "cumin", "alternatives": ["coriander", "caraway"]}
                  ],
                  "required_extra_ingredients": [],
                  "steps": [
                    "Cut the chicken into bite-sized pieces and sear in 2 tablespoons of olive oil over medium-high heat for 8-10 minutes, turning occasionally, until golden brown on all sides.",
                    "Dice the onions finely and sauté in the same pan for 3-4 minutes until translucent and fragrant."
                  ]
                }
              ],
              "extra_ingredient_recipes": [same structure]
            }

            Rules:
            - Give each recipe a unique and creative name. Do NOT use generic or common names.
            - Return exactly \(exactCount) exact_match_recipes and \(extraCount) extra_ingredient_recipes
            - exact_match_recipes use ONLY the user's ingredients plus basic pantry items (water, salt, pepper, oil, butter). required_extra_ingredients must be an empty array [] for these.
            - IMPORTANT: extra_ingredient_recipes use the user's ingredients PLUS 2-4 additional ingredients listed in required_extra_ingredients. required_extra_ingredients must NEVER be empty for these recipes - always include 2-4 extra ingredients the user didn't provide (e.g. ["cream", "mushrooms", "parmesan"])
            - The extra ingredients should be ingredients NOT in the user's list
            - Scale all quantities to the requested servings
            - STEPS MUST BE VERY DETAILED: Every step must include precise timing (e.g. "cook for 5 minutes", "bake for 20 minutes at 180°C"), temperature (e.g. "over medium-high heat", "preheat oven to 200°C"), quantities (e.g. "add 2 tablespoons of oil"), and visual cues (e.g. "until golden brown", "until the sauce thickens"). Do NOT write short vague steps.
            - Each recipe must have 5-8 clear, detailed steps
            - Make recipes realistic, diverse, and cookable
            - No duplicate or near-duplicate recipes
            - In "spices" array, list ALL spices the recipe uses. Each spice must have 2-3 alternatives (substitutes that can replace it).
            - IMPORTANT INGREDIENT CONSISTENCY: Every ingredient used in the steps MUST appear in the "ingredients" or "required_extra_ingredients" list. For example, if a step says "roll out the phyllo dough", then phyllo dough MUST be in the ingredients list. After generating the recipe, review all steps and ensure no ingredient is missing from the lists. Spices are excluded from this rule.
            - Everything must be in English
            \(excludeTitles.isEmpty ? "" : "\n- CRITICAL BANNED LIST: You MUST NOT repeat ANY of the following recipes. Do NOT generate anything similar to them either. Use completely different dish types and cooking methods:\n\(excludeTitles.map { "  * \($0)" }.joined(separator: "\n"))")
            """
        }
    }

    private func buildUserPrompt(ingredients: [String], cuisines: [String], servings: Int, language: String, totalCount: Int, excludeTitles: [String] = []) -> String {
        let ingredientList = ingredients.joined(separator: ", ")
        let cuisineList = cuisines.isEmpty ? (language == "tr" ? "Herhangi bir mutfak" : "Any cuisine") : cuisines.joined(separator: ", ")

        let excludeNote: String
        if !excludeTitles.isEmpty {
            let titles = excludeTitles.joined(separator: ", ")
            if language == "tr" {
                excludeNote = "\n\nÖNEMLİ: Şu tarifleri TEKRAR VERME, tamamen farklı tarifler oluştur: \(titles)"
            } else {
                excludeNote = "\n\nIMPORTANT: Do NOT repeat these recipes, generate completely different ones: \(titles)"
            }
        } else {
            excludeNote = ""
        }

        if language == "tr" {
            return """
            Bu malzemeleri kullanarak \(totalCount) tarif oluştur: \(ingredientList)

            Mutfak tercihleri: \(cuisineList)
            Porsiyon: \(servings)

            Hatırla: SADECE geçerli JSON döndür. Markdown formatı yok. HER ŞEY TÜRKÇE OLMALI — baharat isimleri, adımlar, malzeme isimleri, birimler dahil tamamı Türkçe.\(excludeNote)
            """
        } else {
            return """
            Generate \(totalCount) recipes using these ingredients: \(ingredientList)

            Cuisine preferences: \(cuisineList)
            Servings: \(servings)

            Remember: Return ONLY valid JSON matching the exact schema. No markdown formatting. All content in English.\(excludeNote)
            """
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
