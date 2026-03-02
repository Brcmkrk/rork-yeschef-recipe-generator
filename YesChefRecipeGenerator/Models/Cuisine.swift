import Foundation

nonisolated enum Cuisine: String, CaseIterable, Sendable, Identifiable {
    case turkish = "Turkish"
    case italian = "Italian"
    case mexican = "Mexican"
    case asian = "Asian"
    case french = "French"
    case mediterranean = "Mediterranean"
    case american = "American"
    case indian = "Indian"
    case japanese = "Japanese"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .turkish: return "flame.fill"
        case .italian: return "leaf.fill"
        case .mexican: return "sun.max.fill"
        case .asian: return "wand.and.stars"
        case .french: return "wineglass.fill"
        case .mediterranean: return "fish.fill"
        case .american: return "star.fill"
        case .indian: return "sparkles"
        case .japanese: return "cup.and.saucer.fill"
        }
    }

    func localizedName(language: String) -> String {
        if language == "tr" {
            switch self {
            case .turkish: return "Türk"
            case .italian: return "İtalyan"
            case .mexican: return "Meksika"
            case .asian: return "Asya"
            case .french: return "Fransız"
            case .mediterranean: return "Akdeniz"
            case .american: return "Amerikan"
            case .indian: return "Hint"
            case .japanese: return "Japon"
            }
        } else {
            return rawValue
        }
    }
}
