import Foundation

nonisolated enum IngredientPool {
    static let allEN: [String] = [
        // Proteins
        "chicken breast", "chicken thigh", "chicken wings", "ground beef", "beef steak",
        "lamb", "ground lamb", "pork chops", "bacon", "sausage",
        "salmon", "tuna", "shrimp", "cod", "tilapia",
        "sardines", "mussels", "squid", "crab", "lobster",
        "tofu", "tempeh", "eggs", "turkey", "duck",
        "ham", "pepperoni", "ground turkey", "anchovies", "clams",

        // Grains & Carbs
        "rice", "pasta", "bread", "tortillas", "noodles",
        "couscous", "quinoa", "bulgur", "oats", "flour",
        "cornmeal", "pita bread", "rice noodles", "spaghetti", "penne",
        "lasagna sheets", "breadcrumbs", "croissant", "bagel", "sourdough bread",

        // Vegetables
        "tomatoes", "onions", "garlic", "bell peppers", "broccoli",
        "carrots", "spinach", "mushrooms", "zucchini", "corn",
        "potatoes", "sweet potatoes", "cucumber", "lettuce", "cabbage",
        "cauliflower", "eggplant", "green beans", "peas", "celery",
        "asparagus", "artichoke", "leek", "radish", "beetroot",
        "kale", "arugula", "bok choy", "brussels sprouts", "turnip",
        "okra", "pumpkin", "butternut squash", "jalapeno", "chili peppers",
        "scallions", "shallots", "watercress", "parsnip", "fennel",

        // Fruits
        "lemon", "lime", "avocado", "apple", "banana",
        "orange", "strawberries", "blueberries", "mango", "pineapple",
        "grapes", "watermelon", "peach", "pear", "coconut",
        "pomegranate", "raspberries", "cherries", "dried cranberries", "raisins",

        // Dairy & Alternatives
        "cheese", "mozzarella", "parmesan", "cheddar", "feta",
        "cream cheese", "goat cheese", "ricotta", "milk", "cream",
        "yogurt", "butter", "sour cream", "whipped cream", "condensed milk",
        "coconut milk", "almond milk", "oat milk",

        // Legumes & Nuts
        "beans", "lentils", "chickpeas", "black beans", "kidney beans",
        "white beans", "edamame", "almonds", "walnuts", "peanuts",
        "cashews", "pistachios", "sunflower seeds", "sesame seeds", "pine nuts",
        "chia seeds", "flaxseeds", "peanut butter",

        // Herbs & Spices
        "basil", "parsley", "cilantro", "mint", "rosemary",
        "thyme", "oregano", "dill", "chives", "bay leaves",
        "cumin", "paprika", "turmeric", "cinnamon", "black pepper",
        "cayenne pepper", "coriander", "nutmeg", "cloves", "cardamom",
        "saffron", "curry powder", "chili flakes", "garlic powder", "onion powder",

        // Sauces & Condiments
        "soy sauce", "olive oil", "honey", "ginger", "vinegar",
        "balsamic vinegar", "sesame oil", "hot sauce", "ketchup", "mustard",
        "mayonnaise", "tomato paste", "tomato sauce", "worcestershire sauce", "fish sauce",
        "oyster sauce", "tahini", "sriracha", "barbecue sauce", "salsa",
        "maple syrup", "miso paste",

        // Pantry Staples
        "sugar", "brown sugar", "salt", "baking powder", "baking soda",
        "vanilla extract", "cocoa powder", "chocolate chips", "cornstarch", "gelatin",
        "yeast", "vegetable oil", "canola oil", "rice vinegar", "white wine",
        "red wine", "chicken broth", "beef broth", "vegetable broth", "capers"
    ]

    static let allTR: [String] = [
        // Proteinler
        "tavuk göğsü", "tavuk but", "tavuk kanat", "kıyma", "biftek",
        "kuzu eti", "kuzu kıyma", "pirzola", "pastırma", "sucuk",
        "somon", "ton balığı", "karides", "morina", "levrek",
        "sardalya", "midye", "kalamar", "yengeç", "ıstakoz",
        "tofu", "tempeh", "yumurta", "hindi", "ördek",
        "jambon", "salam", "hindi kıyma", "hamsi", "istiridye",

        // Tahıllar & Karbonhidratlar
        "pirinç", "makarna", "ekmek", "lavaş", "erişte",
        "kuskus", "kinoa", "bulgur", "yulaf", "un",
        "mısır unu", "pide", "pirinç eriştesi", "spagetti", "penne",
        "lazanya yaprağı", "galeta unu", "kruvasan", "simit", "ekşi maya ekmek",

        // Sebzeler
        "domates", "soğan", "sarımsak", "biber", "brokoli",
        "havuç", "ıspanak", "mantar", "kabak", "mısır",
        "patates", "tatlı patates", "salatalık", "marul", "lahana",
        "karnabahar", "patlıcan", "taze fasulye", "bezelye", "kereviz",
        "kuşkonmaz", "enginar", "pırasa", "turp", "pancar",
        "kara lahana", "roka", "pak çoy", "brüksel lahanası", "şalgam",
        "bamya", "balkabağı", "bal kabağı", "jalapeno", "acı biber",
        "yeşil soğan", "arpacık soğan", "tere", "yaban havucu", "rezene",

        // Meyveler
        "limon", "misket limonu", "avokado", "elma", "muz",
        "portakal", "çilek", "yaban mersini", "mango", "ananas",
        "üzüm", "karpuz", "şeftali", "armut", "hindistan cevizi",
        "nar", "ahududu", "kiraz", "kuru kızılcık", "kuru üzüm",

        // Süt Ürünleri
        "peynir", "mozzarella", "parmesan", "kaşar peyniri", "beyaz peynir",
        "krem peynir", "keçi peyniri", "lor peyniri", "süt", "krema",
        "yoğurt", "tereyağı", "ekşi krema", "çırpılmış krema", "yoğun süt",
        "hindistan cevizi sütü", "badem sütü", "yulaf sütü",

        // Baklagiller & Kuruyemişler
        "fasulye", "mercimek", "nohut", "siyah fasulye", "barbunya",
        "kuru fasulye", "soya fasulyesi", "badem", "ceviz", "fıstık",
        "kaju", "antep fıstığı", "ayçekirdeği", "susam", "çam fıstığı",
        "chia tohumu", "keten tohumu", "fıstık ezmesi",

        // Otlar & Baharatlar
        "fesleğen", "maydanoz", "kişniş", "nane", "biberiye",
        "kekik", "mercanköşk", "dereotu", "frenk soğanı", "defne yaprağı",
        "kimyon", "kırmızı biber", "zerdeçal", "tarçın", "karabiber",
        "pul biber", "kişniş tohumu", "muskat", "karanfil", "kakule",
        "safran", "köri", "biber pul", "sarımsak tozu", "soğan tozu",

        // Soslar & Çeşniler
        "soya sosu", "zeytinyağı", "bal", "zencefil", "sirke",
        "balzamik sirke", "susam yağı", "acı sos", "ketçap", "hardal",
        "mayonez", "domates salçası", "domates sosu", "worcestershire sosu", "balık sosu",
        "istiridye sosu", "tahin", "sriracha", "barbekü sos", "salsa",
        "akçaağaç şurubu", "miso",

        // Mutfak Malzemeleri
        "şeker", "esmer şeker", "tuz", "kabartma tozu", "karbonat",
        "vanilya özütü", "kakao", "çikolata parçacıkları", "nişasta", "jelatin",
        "maya", "ayçiçek yağı", "kanola yağı", "pirinç sirkesi", "beyaz şarap",
        "kırmızı şarap", "tavuk suyu", "et suyu", "sebze suyu", "kapari"
    ]

    static func random(count: Int = 5, language: String = "en") -> [String] {
        let pool = language == "tr" ? allTR : allEN
        return Array(pool.shuffled().prefix(count))
    }
}
