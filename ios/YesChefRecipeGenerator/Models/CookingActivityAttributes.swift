import ActivityKit
import Foundation

nonisolated struct CookingActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var timerEndDate: Date
        var isRunning: Bool
        var stepNumber: Int
        var totalSteps: Int
    }

    var recipeName: String
    var totalSeconds: Int
}
