import Foundation

class RecipeCacheService {
    static let shared = RecipeCacheService()

    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 60 * 60 * 24 * 3
    private let maxCacheEntries = 50
    private var memoryCache: [String: CacheEntry] = [:]

    private init() {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("RecipeCache", isDirectory: true)
        try? fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        loadIndex()
    }

    func cachedResponse(for key: String) -> RecipeResponse? {
        if let entry = memoryCache[key], !entry.isExpired(maxAge: maxCacheAge) {
            return entry.response
        }

        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(CacheEntry.self, from: data)
            guard !entry.isExpired(maxAge: maxCacheAge) else {
                try? FileManager.default.removeItem(at: fileURL)
                memoryCache.removeValue(forKey: key)
                return nil
            }
            memoryCache[key] = entry
            return entry.response
        } catch {
            return nil
        }
    }

    func store(response: RecipeResponse, for key: String) {
        let entry = CacheEntry(response: response, timestamp: Date())
        memoryCache[key] = entry

        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL, options: .atomic)
        }

        pruneIfNeeded()
    }

    func cachedTranslation(for recipeIDs: [String], language: String) -> [Recipe]? {
        let key = translationKey(recipeIDs: recipeIDs, language: language)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(TranslationCacheEntry.self, from: data)
            guard !entry.isExpired(maxAge: maxCacheAge) else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return entry.recipes
        } catch {
            return nil
        }
    }

    func storeTranslation(_ recipes: [Recipe], recipeIDs: [String], language: String) {
        let key = translationKey(recipeIDs: recipeIDs, language: language)
        let entry = TranslationCacheEntry(recipes: recipes, timestamp: Date())
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func cacheKey(
        ingredients: [String],
        cuisines: [String],
        servings: Int,
        language: String,
        exactCount: Int,
        extraCount: Int
    ) -> String {
        let sortedIngredients = ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }.sorted()
        let sortedCuisines = cuisines.map { $0.lowercased() }.sorted()
        let raw = "\(sortedIngredients.joined(separator: "|"))_\(sortedCuisines.joined(separator: "|"))_\(servings)_\(language)_\(exactCount)_\(extraCount)"
        return raw.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(64)
            .description
    }

    private func translationKey(recipeIDs: [String], language: String) -> String {
        let raw = "tr_\(recipeIDs.sorted().joined(separator: "|"))_\(language)"
        return raw.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(64)
            .description
    }

    private func loadIndex() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files where file.pathExtension == "json" {
            let key = file.deletingPathExtension().lastPathComponent
            if let data = try? Data(contentsOf: file),
               let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
               !entry.isExpired(maxAge: maxCacheAge) {
                memoryCache[key] = entry
            }
        }
    }

    private func pruneIfNeeded() {
        guard memoryCache.count > maxCacheEntries else { return }
        let sorted = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = sorted.prefix(memoryCache.count - maxCacheEntries)
        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
            let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

nonisolated struct CacheEntry: Codable, Sendable {
    let response: RecipeResponse
    let timestamp: Date

    func isExpired(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

nonisolated struct TranslationCacheEntry: Codable, Sendable {
    let recipes: [Recipe]
    let timestamp: Date

    func isExpired(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}
