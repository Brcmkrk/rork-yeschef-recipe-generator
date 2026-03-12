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
        case .english: return "\u{1F1EC}\u{1F1E7}"
        case .turkish: return "\u{1F1F9}\u{1F1F7}"
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
