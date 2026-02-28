import Foundation

nonisolated enum ReactionType: String, Codable, Sendable {
    case like
    case dislike
    case none
}

@Observable
class LikesStore {
    var reactions: [String: ReactionType] = [:]
    var likedRecipes: [Recipe] = []
    var globalCounts: [String: RecipeCounts] = [:]
    private let reactionsKey = "recipe_reactions_local"
    private let likedRecipesKey = "liked_recipes_local"

    init() {
        loadLocal()
        Task { await syncFromSupabase() }
    }

    func reaction(for id: String) -> ReactionType {
        reactions[id] ?? .none
    }

    func toggleLike(for id: String, recipe: Recipe) {
        let current = reaction(for: id)
        if current == .like {
            reactions[id] = .none
            likedRecipes.removeAll { $0.id == id }
            adjustLocalCount(id: id, removingReaction: .like)
            saveLocal()
            Task { try? await SupabaseService.shared.deleteReaction(recipeId: id) }
        } else {
            if current == .dislike {
                adjustLocalCount(id: id, removingReaction: .dislike)
            }
            reactions[id] = .like
            adjustLocalCount(id: id, addingReaction: .like)
            if !likedRecipes.contains(where: { $0.id == id }) {
                likedRecipes.insert(recipe, at: 0)
            }
            saveLocal()
            Task { try? await SupabaseService.shared.upsertReaction(recipeId: id, recipe: recipe, reaction: "like") }
        }
    }

    func toggleDislike(for id: String, recipe: Recipe) {
        let current = reaction(for: id)
        if current == .dislike {
            reactions[id] = .none
            adjustLocalCount(id: id, removingReaction: .dislike)
            saveLocal()
            Task { try? await SupabaseService.shared.deleteReaction(recipeId: id) }
        } else {
            if current == .like {
                adjustLocalCount(id: id, removingReaction: .like)
            }
            reactions[id] = .dislike
            adjustLocalCount(id: id, addingReaction: .dislike)
            likedRecipes.removeAll { $0.id == id }
            saveLocal()
            Task { try? await SupabaseService.shared.upsertReaction(recipeId: id, recipe: recipe, reaction: "dislike") }
        }
    }

    func removeLikedRecipe(_ recipe: Recipe) {
        let current = reaction(for: recipe.id)
        if current != .none {
            adjustLocalCount(id: recipe.id, removingReaction: current)
        }
        reactions[recipe.id] = .none
        likedRecipes.removeAll { $0.id == recipe.id }
        saveLocal()
        Task { try? await SupabaseService.shared.deleteReaction(recipeId: recipe.id) }
    }

    func likesCount(for id: String) -> Int {
        globalCounts[id]?.likes ?? 0
    }

    func dislikesCount(for id: String) -> Int {
        globalCounts[id]?.dislikes ?? 0
    }

    func fetchGlobalCounts(for recipes: [Recipe]) {
        let ids = recipes.map(\.id)
        Task {
            let counts = await SupabaseService.shared.fetchGlobalCounts(recipeIds: ids)
            globalCounts.merge(counts) { _, new in new }
        }
    }

    private func adjustLocalCount(id: String, addingReaction: ReactionType) {
        var c = globalCounts[id] ?? RecipeCounts()
        if addingReaction == .like { c.likes += 1 }
        else if addingReaction == .dislike { c.dislikes += 1 }
        globalCounts[id] = c
    }

    private func adjustLocalCount(id: String, removingReaction: ReactionType) {
        var c = globalCounts[id] ?? RecipeCounts()
        if removingReaction == .like { c.likes = max(0, c.likes - 1) }
        else if removingReaction == .dislike { c.dislikes = max(0, c.dislikes - 1) }
        globalCounts[id] = c
    }

    func syncFromSupabase() async {
        guard SupabaseService.shared.isConfigured else { return }
        do {
            let remoteReactions = try await SupabaseService.shared.fetchMyReactions()
            var newReactions: [String: ReactionType] = [:]
            var newLiked: [Recipe] = []

            for r in remoteReactions {
                let type: ReactionType = r.reaction == "like" ? .like : .dislike
                newReactions[r.recipe_id] = type

                if type == .like, let recipeData = r.recipe_data.data(using: .utf8),
                   let recipe = try? JSONDecoder().decode(Recipe.self, from: recipeData) {
                    newLiked.append(recipe)
                }
            }

            reactions = newReactions
            likedRecipes = newLiked
            saveLocal()
        } catch {
            // keep local data on failure
        }
    }

    private func loadLocal() {
        if let data = UserDefaults.standard.data(forKey: reactionsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            reactions = decoded.compactMapValues { ReactionType(rawValue: $0) }
        }
        if let data = UserDefaults.standard.data(forKey: likedRecipesKey),
           let decoded = try? JSONDecoder().decode([Recipe].self, from: data) {
            likedRecipes = decoded
        }
    }

    private func saveLocal() {
        let stringReactions = reactions.compactMapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(stringReactions) {
            UserDefaults.standard.set(data, forKey: reactionsKey)
        }
        if let data = try? JSONEncoder().encode(likedRecipes) {
            UserDefaults.standard.set(data, forKey: likedRecipesKey)
        }
    }
}
