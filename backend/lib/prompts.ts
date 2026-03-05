// ─── Phase 1: Preview Prompts ────────────────────────────────────────────────
// Only returns: id, title, description, calories, cuisine, difficulty,
// servings, ingredients, required_extra_ingredients
// NO steps, NO spices

export function buildPreviewSystemPrompt(
  language: string,
  exactCount: number,
  extraCount: number,
  excludeTitles: string[]
): string {
  const isTurkish = language === "tr";
  const bannedList = excludeTitles.length > 0
    ? (isTurkish
      ? `\n- YASAK: Şu tarifleri TEKRAR VERME:\n${excludeTitles.map(t => `  * ${t}`).join("\n")}`
      : `\n- BANNED: Do NOT generate any of these recipes:\n${excludeTitles.map(t => `  * ${t}`).join("\n")}`)
    : "";

  if (isTurkish) {
    return `Sen profesyonel bir şef ve tarif oluşturucusun. SADECE geçerli JSON döndür.

BU BİR ÖNİZLEME İSTEĞİDİR — "steps" ve "spices" alanları EKLEME.

Döndürmen gereken JSON yapısı:
{
  "exact_match_recipes": [
    {
      "id": "benzersiz_string",
      "title": "Tarif Adı",
      "calories": "300-400",
      "cuisine": "İtalyan",
      "difficulty": "Kolay|Orta|Zor",
      "description": "1-2 cümlelik kısa açıklama",
      "servings": 2,
      "ingredients": [{"name": "tavuk", "quantity": "500", "unit": "g"}],
      "required_extra_ingredients": []
    }
  ],
  "extra_ingredient_recipes": [aynı yapı]
}

Kurallar:
- Tam olarak ${exactCount} exact_match_recipes ve ${extraCount} extra_ingredient_recipes döndür
- exact_match_recipes: sadece kullanıcının malzemeleri + temel mutfak malzemeleri (tuz, yağ, su). required_extra_ingredients = []
- extra_ingredient_recipes: kullanıcı malzemeleri + required_extra_ingredients'te 2-4 ek malzeme
- HER ŞEY TÜRKÇE OLMALI${bannedList}`;
  } else {
    return `You are a professional chef. Respond with ONLY valid JSON.

THIS IS A PREVIEW REQUEST — Do NOT include "steps" or "spices" fields.

Return this JSON structure:
{
  "exact_match_recipes": [
    {
      "id": "unique_string",
      "title": "Recipe Name",
      "calories": "300-400",
      "cuisine": "Italian",
      "difficulty": "Easy|Medium|Hard",
      "description": "Short 1-2 sentence description",
      "servings": 2,
      "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
      "required_extra_ingredients": []
    }
  ],
  "extra_ingredient_recipes": [same structure]
}

Rules:
- Return exactly ${exactCount} exact_match_recipes and ${extraCount} extra_ingredient_recipes
- exact_match_recipes: use only user's ingredients + basic pantry items (salt, oil, water). required_extra_ingredients = []
- extra_ingredient_recipes: user ingredients + 2-4 extra ingredients listed in required_extra_ingredients
- All content in English${bannedList}`;
  }
}

export function buildPreviewUserPrompt(
  ingredients: string[],
  cuisines: string[],
  servings: number,
  language: string,
  totalCount: number,
  excludeTitles: string[]
): string {
  const ingredientList = ingredients.join(", ");
  const cuisineList = cuisines.length === 0
    ? (language === "tr" ? "Herhangi bir mutfak" : "Any cuisine")
    : cuisines.join(", ");

  let excludeNote = "";
  if (excludeTitles.length > 0) {
    const titles = excludeTitles.join(", ");
    excludeNote = language === "tr"
      ? `\n\nÖNEMLİ: Şu tarifleri TEKRAR VERME: ${titles}`
      : `\n\nIMPORTANT: Do NOT repeat these recipes: ${titles}`;
  }

  if (language === "tr") {
    return `Bu malzemeleri kullanarak ${totalCount} tarif oluştur: ${ingredientList}

Mutfak tercihleri: ${cuisineList}
Porsiyon: ${servings}

SADECE geçerli JSON döndür. HER ŞEY TÜRKÇE OLMALI.${excludeNote}`;
  } else {
    return `Generate ${totalCount} recipes using these ingredients: ${ingredientList}

Cuisine preferences: ${cuisineList}
Servings: ${servings}

Return ONLY valid JSON. All content in English.${excludeNote}`;
  }
}

// ─── Phase 2: Expand Prompts ─────────────────────────────────────────────────
// Given recipe previews, generates steps + spices

export function buildExpandSystemPrompt(language: string): string {
  const isTurkish = language === "tr";

  if (isTurkish) {
    return `Sen profesyonel bir şefsin. Sana tarif önizlemeleri verilecek. Her tarif için detaylı adımlar ve baharatlar oluştur.

SADECE geçerli JSON döndür.

Döndürmen gereken yapı:
{
  "recipes": [
    {
      "id": "orijinal_tarif_id",
      "steps": [
        "Tavuğu küçük parçalara kesin ve orta ateşte 2 yemek kaşığı zeytinyağında 8-10 dakika altın rengi olana kadar kavurun.",
        "Soğanları ince doğrayın ve aynı tavada 3-4 dakika şeffaflaşana kadar soteleyin."
      ],
      "spices": [
        {"name": "tuz", "alternatives": ["deniz tuzu", "himalaya tuzu"]},
        {"name": "karabiber", "alternatives": ["beyaz biber", "yeşil biber"]}
      ]
    }
  ]
}

Kurallar:
- Her tarifin 5-8 detaylı adımı olsun
- Her adımda kesin süre (dakika), sıcaklık ve görsel ipuçları ver
- spices dizisinde kullanılan TÜM baharatları listele, her birinin 2-3 alternatifi olsun
- Adımlarda geçen her malzeme tarif malzeme listesinde olmalı
- HER ŞEY TÜRKÇE OLMALI`;
  } else {
    return `You are a professional chef. You will be given recipe previews. Generate detailed steps and spices for each recipe.

Respond with ONLY valid JSON.

Return this structure:
{
  "recipes": [
    {
      "id": "original_recipe_id",
      "steps": [
        "Cut the chicken into bite-sized pieces and sear in 2 tablespoons of olive oil over medium-high heat for 8-10 minutes until golden brown.",
        "Dice the onions finely and sauté in the same pan for 3-4 minutes until translucent."
      ],
      "spices": [
        {"name": "salt", "alternatives": ["sea salt", "pink salt"]},
        {"name": "black pepper", "alternatives": ["white pepper", "green peppercorn"]}
      ]
    }
  ]
}

Rules:
- Each recipe must have 5-8 clear, detailed steps
- Every step must include precise timing, temperature, quantities, and visual cues
- List ALL spices used with 2-3 alternatives each
- Every ingredient mentioned in steps must exist in the recipe's ingredients list
- All content in English`;
  }
}

export function buildExpandUserPrompt(recipes: any[], language: string): string {
  const summaries = recipes.map(r => ({
    id: r.id,
    title: r.title,
    ingredients: (r.ingredients || []).map((i: any) => i.name || i),
    required_extra_ingredients: r.required_extra_ingredients || [],
    servings: r.servings,
  }));

  if (language === "tr") {
    return `Şu tarifler için detaylı adımlar ve baharatlar oluştur:\n${JSON.stringify(summaries, null, 2)}\n\nSADECE geçerli JSON döndür. HER ŞEY TÜRKÇE.`;
  } else {
    return `Generate detailed steps and spices for these recipes:\n${JSON.stringify(summaries, null, 2)}\n\nReturn ONLY valid JSON. All content in English.`;
  }
}
