import Foundation

nonisolated enum IngredientPool {
    static let allEN: [String] = [
        "chicken breast", "ground beef", "salmon", "shrimp", "tofu",
        "rice", "pasta", "potatoes", "bread", "tortillas",
        "tomatoes", "onions", "garlic", "bell peppers", "broccoli",
        "carrots", "spinach", "mushrooms", "zucchini", "corn",
        "cheese", "eggs", "milk", "cream", "yogurt",
        "lemon", "avocado", "beans", "lentils", "chickpeas",
        "soy sauce", "olive oil", "coconut milk", "honey", "ginger"
    ]

    static let allTR: [String] = [
        "tavuk göğsü", "kıyma", "somon", "karides", "tofu",
        "pirinç", "makarna", "patates", "ekmek", "lavaş",
        "domates", "soğan", "sarımsak", "biber", "brokoli",
        "havuç", "ıspanak", "mantar", "kabak", "mısır",
        "peynir", "yumurta", "süt", "krema", "yoğurt",
        "limon", "avokado", "fasulye", "mercimek", "nohut",
        "soya sosu", "zeytinyağı", "hindistan cevizi sütü", "bal", "zencefil"
    ]

    static func random(count: Int = 5, language: String = "en") -> [String] {
        let pool = language == "tr" ? allTR : allEN
        return Array(pool.shuffled().prefix(count))
    }
}
