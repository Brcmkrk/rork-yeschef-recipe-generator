import SwiftUI

nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case turkish = "tr"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .turkish: return "🇹🇷"
        }
    }
}

@Observable
class LanguageManager {
    var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "app_language")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        self.current = AppLanguage(rawValue: saved) ?? .english
    }

    func t(_ en: String, _ tr: String) -> String {
        current == .turkish ? tr : en
    }
}
