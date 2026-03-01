import Foundation

@Observable
class StatsStore {
    static let shared = StatsStore()

    var totalLiked: Int = 0
    var totalTried: Int = 0

    private let likedKey = "stats_total_liked"
    private let triedKey = "stats_total_tried"

    init() {
        totalLiked = UserDefaults.standard.integer(forKey: likedKey)
        totalTried = UserDefaults.standard.integer(forKey: triedKey)
    }

    func incrementLiked() {
        totalLiked += 1
        UserDefaults.standard.set(totalLiked, forKey: likedKey)
    }

    func decrementLiked() {
        totalLiked = max(0, totalLiked - 1)
        UserDefaults.standard.set(totalLiked, forKey: likedKey)
    }

    func incrementTried() {
        totalTried += 1
        UserDefaults.standard.set(totalTried, forKey: triedKey)
    }
}
