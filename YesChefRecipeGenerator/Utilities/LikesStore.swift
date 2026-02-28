import Foundation

@Observable
class LikesStore {
    var likes: [String: Int] = [:]
    var dislikes: [String: Int] = [:]

    private let likesKey = "recipe_likes"
    private let dislikesKey = "recipe_dislikes"

    init() {
        load()
    }

    func likeCount(for id: String) -> Int {
        likes[id] ?? 0
    }

    func dislikeCount(for id: String) -> Int {
        dislikes[id] ?? 0
    }

    func toggleLike(for id: String) {
        likes[id] = (likes[id] ?? 0) + 1
        save()
    }

    func toggleDislike(for id: String) {
        dislikes[id] = (dislikes[id] ?? 0) + 1
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: likesKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            likes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: dislikesKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            dislikes = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(likes) {
            UserDefaults.standard.set(data, forKey: likesKey)
        }
        if let data = try? JSONEncoder().encode(dislikes) {
            UserDefaults.standard.set(data, forKey: dislikesKey)
        }
    }
}
