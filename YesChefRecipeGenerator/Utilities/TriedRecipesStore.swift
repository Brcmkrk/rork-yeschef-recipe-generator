import Foundation

@Observable
class TriedRecipesStore {
    var recipes: [Recipe] = []
    private let key = "tried_recipes"

    init() {
        load()
    }

    func add(_ recipe: Recipe) {
        guard !recipes.contains(where: { $0.id == recipe.id }) else { return }
        recipes.insert(recipe, at: 0)
        save()
    }

    func remove(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        save()
    }

    func contains(_ recipe: Recipe) -> Bool {
        recipes.contains(where: { $0.id == recipe.id })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
