import { Hono } from "hono";
import { cors } from "hono/cors";

const app = new Hono();

app.use("*", cors());

app.get("/", (c) => {
  return c.json({ status: "ok", message: "YesChef API is running" });
});

app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 20;
const RATE_WINDOW_MS = 60_000;

function checkRateLimit(deviceId: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(deviceId);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(deviceId, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  if (entry.count >= RATE_LIMIT) return false;
  entry.count++;
  return true;
}

function buildPreviewSystemPrompt(
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

function buildPreviewUserPrompt(
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

function buildExpandSystemPrompt(language: string): string {
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

function buildExpandUserPrompt(recipes: any[], language: string): string {
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

async function callOpenAI(messages: any[], temperature: number, maxTokens: number, jsonMode: boolean = false) {
  const apiKey = process.env.EXPO_PUBLIC_OPENAI_API_KEY || process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OpenAI API key not configured");
  }

  const body: any = {
    model: "gpt-4o-mini",
    messages,
    temperature,
    max_tokens: maxTokens,
  };

  if (jsonMode) {
    body.response_format = { type: "json_object" };
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content || null;
}

app.post("/generate-recipe-previews", async (c) => {
  try {
    const body = await c.req.json();
    const {
      ingredients,
      cuisines,
      servings,
      language = "en",
      exactCount = 2,
      extraCount = 2,
      excludeTitles = [],
      deviceId,
    } = body;

    if (!deviceId || !ingredients || !Array.isArray(ingredients)) {
      return c.json({ error: "Missing required fields" }, 400);
    }

    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded. Please wait a moment." }, 429);
    }

    const systemPrompt = buildPreviewSystemPrompt(language, exactCount, extraCount, excludeTitles);
    const userPrompt = buildPreviewUserPrompt(ingredients, cuisines || [], servings || 2, language, exactCount + extraCount, excludeTitles);

    console.log(`[PREVIEW] ${language} | ${exactCount}+${extraCount} recipes | ingredients: ${ingredients.join(", ")}`);

    const content = await callOpenAI(
      [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      0.85,
      Math.min(1200, Math.max(600, (exactCount + extraCount) * 280)),
      true
    );

    if (!content) {
      return c.json({ error: "No response from AI" }, 500);
    }

    let parsed: any;
    try {
      parsed = JSON.parse(content);
    } catch {
      return c.json({ error: "Failed to parse AI response" }, 500);
    }

    const sanitizePreview = (r: any) => ({
      id: r.id || `recipe_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      title: String(r.title || ""),
      description: String(r.description || ""),
      calories: String(r.calories || ""),
      cuisine: String(r.cuisine || ""),
      difficulty: String(r.difficulty || ""),
      servings: Number(r.servings || 2),
      ingredients: (r.ingredients || []).map((i: any) => ({
        name: String(i.name || ""),
        quantity: String(i.quantity ?? ""),
        unit: String(i.unit ?? ""),
      })),
      required_extra_ingredients: (r.required_extra_ingredients || []).map(String),
      steps: [],
      spices: [],
      source: "generated",
    });

    const exactRecipes = (parsed.exact_match_recipes || []).map(sanitizePreview).slice(0, exactCount);
    const extraRecipes = (parsed.extra_ingredient_recipes || []).map(sanitizePreview).slice(0, extraCount);

    console.log(`[PREVIEW] Returning ${exactRecipes.length} exact + ${extraRecipes.length} extra`);

    return c.json({
      exact_match_recipes: exactRecipes,
      extra_ingredient_recipes: extraRecipes,
    });

  } catch (err: any) {
    console.error("[PREVIEW] Error:", err);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

app.post("/expand-recipes", async (c) => {
  try {
    const body = await c.req.json();
    const { recipes, language = "en", deviceId } = body;

    if (!deviceId || !recipes || !Array.isArray(recipes) || recipes.length === 0) {
      return c.json({ error: "Missing required fields" }, 400);
    }

    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded. Please wait a moment." }, 429);
    }

    const recipe = recipes[0];
    console.log(`[EXPAND] Expanding "${recipe.title}" (${language})`);

    const systemPrompt = buildExpandSystemPrompt(language);
    const userPrompt = buildExpandUserPrompt([recipe], language);

    const content = await callOpenAI(
      [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      0.75,
      1200,
      true
    );

    if (!content) {
      return c.json({ error: "No response from AI" }, 500);
    }

    let parsed: any;
    try {
      parsed = JSON.parse(content);
    } catch {
      return c.json({ error: "Failed to parse AI response" }, 500);
    }

    const expandedList = parsed.recipes || [];
    console.log(`[EXPAND] Done — ${expandedList.length} recipe(s) expanded`);

    return c.json({ recipes: expandedList });

  } catch (err: any) {
    console.error("[EXPAND] Error:", err);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

app.post("/translate-recipes", async (c) => {
  try {
    const body = await c.req.json();
    const { recipes, targetLanguage, deviceId } = body;

    if (!deviceId || !recipes || !Array.isArray(recipes)) {
      return c.json({ error: "Missing required fields" }, 400);
    }

    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded. Please wait a moment." }, 429);
    }

    const targetLang = targetLanguage === "tr" ? "Turkish" : "English";

    const systemPrompt = `You are a translator. Translate the given recipe JSON array into ${targetLang}.
Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, ingredient units, steps, required_extra_ingredients.
For the "spices" array: translate each spice "name" and all "alternatives" strings.
Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
For difficulty, use: ${targetLanguage === "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard"}
Respond with ONLY the translated JSON array. No markdown, no extra text.`;

    const content = await callOpenAI(
      [
        { role: "system", content: systemPrompt },
        { role: "user", content: JSON.stringify(recipes) },
      ],
      0.3,
      8000,
      false
    );

    if (!content) {
      return c.json({ error: "No response from AI" }, 500);
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      const parsed = JSON.parse(cleaned);
      return c.json(parsed);
    } catch {
      return c.json({ error: "Failed to parse translation response" }, 500);
    }

  } catch (err: any) {
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

export default app;
