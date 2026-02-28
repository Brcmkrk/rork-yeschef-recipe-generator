import Foundation

nonisolated enum IngredientPool {
    static let all: [String] = [
        "chicken breast", "ground beef", "salmon", "shrimp", "tofu",
        "rice", "pasta", "potatoes", "bread", "tortillas",
        "tomatoes", "onions", "garlic", "bell peppers", "broccoli",
        "carrots", "spinach", "mushrooms", "zucchini", "corn",
        "cheese", "eggs", "milk", "cream", "yogurt",
        "lemon", "avocado", "beans", "lentils", "chickpeas",
        "soy sauce", "olive oil", "coconut milk", "honey", "ginger"
    ]

    static func random(count: Int = 5) -> [String] {
        Array(all.shuffled().prefix(count))
    }
}
