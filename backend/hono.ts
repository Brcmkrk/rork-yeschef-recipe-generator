/**
 * YesChef Backend — Hono API
 *
 * Architecture:
 *   POST /generate-recipe-previews  → Phase 1: Quick preview (title, description, ingredients)
 *   POST /expand-recipes            → Phase 2: Full generation (steps, spices) — one recipe at a time
 *   POST /translate-recipes         → Translate recipe array to target language
 *
 *   POST /reactions/upsert          → Save/update a recipe reaction (like, dislike, save)
 *   DELETE /reactions/:userId/:recipeId → Remove a reaction
 *   GET /reactions/:userId/:recipeId    → Get a single reaction
 *
 *   POST /tried                     → Mark a recipe as tried
 *   GET /tried/:userId              → List tried recipes for a user
 *
 *   GET /health                     → Health check
 */

import { Hono } from "hono";
import { cors } from "hono/cors";
import {
  supabase,
  getRecipeReaction,
  upsertRecipeReaction,
  deleteRecipeReaction,
  getTriedRecipes,
  markRecipeAsTried,
} from "./lib/supabase";

// ── OpenAI Key ───────────────────────────────────────────────────────────────
function getOpenAIKey(): string {
  return (
    process.env.OPENAI_API_KEY ||
    process.env.EXPO_PUBLIC_OPENAI_API_KEY ||
    ""
  );
}

// ── OpenAI Helper ────────────────────────────────────────────────────────────
async function callOpenAI(
  messages: Array<{ role: string; content: string }>,
  temperature: number,
  maxTokens: number,
  jsonMode = false
): Promise<string | null> {
  const apiKey = getOpenAIKey();
  if (!apiKey) throw new Error("OpenAI API key not configured");

  const body: Record<string, any> = {
    model: "gpt-4o-mini",
    messages,
    temperature,
    max_tokens: maxTokens,
  };
  if (jsonMode) body.response_format = { type: "json_object" };

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`OpenAI error (${response.status}): ${err.slice(0, 300)}`);
  }

  const data: any = await response.json();
  return data.choices?.[0]?.message?.content ?? null;
}

// ── Prompt Builders ──────────────────────────────────────────────────────────
function previewSystemPrompt(language: string, exactCount: number, extraCount: number, exclude: string[]): string {
  const tr = language === "tr";
  const banned = exclude.length
    ? (tr
      ? `\n- YASAK LİSTE: Şu tarifleri TEKRAR VERME:\n${exclude.map(t => `  * ${t}`).join("\n")}`
      : `\n- BANNED: Do NOT generate these recipes:\n${exclude.map(t => `  * ${t}`).join("\n")}`)
    : "";

  if (tr) {
    return `Sen profesyonel bir şefsin. SADECE geçerli JSON döndür. Bu bir ÖNİZLEME isteğidir — "steps" ve "spices" alanlarını EKLEME.

JSON yapısı:
{
  "exact_match_recipes": [{
    "id": "benzersiz_id",
    "title": "Tarif Adı",
    "calories": "300-400",
    "cuisine": "Türk",
    "difficulty": "Kolay",
    "description": "Kısa 1-2 cümle açıklama.",
    "servings": 2,
    "ingredients": [{"name": "tavuk", "quantity": "500", "unit": "g"}],
    "required_extra_ingredients": []
  }],
  "extra_ingredient_recipes": [aynı yapı]
}

Kurallar:
- TAM OLARAK ${exactCount} exact_match_recipes ve ${extraCount} extra_ingredient_recipes döndür
- exact_match: SADECE kullanıcı malzemeleri + temel mutfak (tuz, yağ, su). required_extra_ingredients = []
- extra_ingredient: kullanıcı malzemeleri + required_extra_ingredients'te 2-4 YENİ malzeme (asla boş olma)
- HER ŞEY TÜRKÇE${banned}`;
  } else {
    return `You are a professional chef. Return ONLY valid JSON. This is a PREVIEW request — do NOT include "steps" or "spices".

JSON structure:
{
  "exact_match_recipes": [{
    "id": "unique_id",
    "title": "Recipe Name",
    "calories": "300-400",
    "cuisine": "Italian",
    "difficulty": "Easy",
    "description": "Short 1-2 sentence description.",
    "servings": 2,
    "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
    "required_extra_ingredients": []
  }],
  "extra_ingredient_recipes": [same structure]
}

Rules:
- Return EXACTLY ${exactCount} exact_match_recipes and ${extraCount} extra_ingredient_recipes
- exact_match: user's ingredients + basic pantry only (salt, oil, water). required_extra_ingredients = []
- extra_ingredient: user ingredients + 2-4 NEW ingredients in required_extra_ingredients (never empty)
- All content in English${banned}`;
  }
}

function previewUserPrompt(ingredients: string[], cuisines: string[], servings: number, language: string, total: number, exclude: string[]): string {
  const tr = language === "tr";
  const ingStr = ingredients.join(", ");
  const cuiStr = cuisines.length ? cuisines.join(", ") : (tr ? "Herhangi" : "Any");
  const excludeNote = exclude.length
    ? (tr ? `\nÖNEMLİ: Şu tarifleri TEKRAR VERME: ${exclude.join(", ")}` : `\nIMPORTANT: Do NOT repeat: ${exclude.join(", ")}`)
    : "";

  if (tr) {
    return `Bu malzemeleri kullanarak ${total} tarif oluştur: ${ingStr}\nMutfak: ${cuiStr} | Porsiyon: ${servings}\nSADECE JSON döndür. HER ŞEY TÜRKÇE.${excludeNote}`;
  }
  return `Create ${total} recipes using: ${ingStr}\nCuisine: ${cuiStr} | Servings: ${servings}\nReturn ONLY JSON. All English.${excludeNote}`;
}

function expandSystemPrompt(language: string): string {
  const tr = language === "tr";

  if (tr) {
    return `Sen profesyonel bir şefsin. Verilen tarif için DETAYLI adımlar ve baharatlar üret. SADECE geçerli JSON döndür.

Yapı:
{
  "recipes": [{
    "id": "orijinal_id",
    "steps": [
      "Tavuğu 2 cm küpler halinde kesin. Orta-yüksek ateşte 2 yemek kaşığı zeytinyağı ısıtın.",
      "Tavuğu 8-10 dakika, her tarafı altın rengi olana kadar kavurun."
    ],
    "spices": [
      {"name": "tuz", "alternatives": ["deniz tuzu", "himalaya tuzu"]},
      {"name": "karabiber", "alternatives": ["beyaz biber", "yeşil biber"]}
    ]
  }]
}

Kurallar:
- 5-8 detaylı adım: kesin süre (örn. "8 dakika"), sıcaklık (örn. "180°C"), miktar ve görsel ipuçları zorunlu
- Kullanılan TÜM baharatları listele, her birinin 2-3 alternatifi olsun
- HER ŞEY TÜRKÇE`;
  } else {
    return `You are a professional chef. Generate DETAILED steps and spices for the given recipe. Return ONLY valid JSON.

Structure:
{
  "recipes": [{
    "id": "original_id",
    "steps": [
      "Cut chicken into 2cm cubes. Heat 2 tablespoons olive oil in a pan over medium-high heat.",
      "Sear chicken for 8-10 minutes until golden brown on all sides."
    ],
    "spices": [
      {"name": "salt", "alternatives": ["sea salt", "pink himalayan salt"]},
      {"name": "black pepper", "alternatives": ["white pepper", "cayenne"]}
    ]
  }]
}

Rules:
- 5-8 detailed steps: must include exact timing, temperature, quantities, and visual cues
- List ALL spices used, each with 2-3 alternatives
- All content in English`;
  }
}

function expandUserPrompt(recipes: any[], language: string): string {
  const summaries = recipes.map(r => ({
    id: r.id,
    title: r.title,
    servings: r.servings,
    ingredients: (r.ingredients || []).map((i: any) => `${i.quantity ?? ""} ${i.unit ?? ""} ${i.name ?? ""}`.trim()),
    extra_ingredients: r.required_extra_ingredients || [],
  }));

  const tr = language === "tr";
  if (tr) {
    return `Bu tarif için adımlar ve baharatlar üret:\n${JSON.stringify(summaries, null, 2)}\n\nSADECE JSON. HER ŞEY TÜRKÇE.`;
  }
  return `Generate steps and spices for this recipe:\n${JSON.stringify(summaries, null, 2)}\n\nReturn ONLY JSON. All English.`;
}

// ── Rate Limiter ─────────────────────────────────────────────────────────────
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

// ── Sanitizers ───────────────────────────────────────────────────────────────
function sanitizePreview(r: any, language = "en") {
  return {
    id: r.id || `r_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
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
    language,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
const app = new Hono();
app.use("*", cors());

// ── Health ────────────────────────────────────────────────────────────────────
app.get("/", (c) => c.json({ status: "ok", version: "2.0", message: "YesChef API is running" }));
app.get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }));

// ── Phase 1: Generate Previews ────────────────────────────────────────────────
app.post("/generate-recipe-previews", async (c) => {
  try {
    const body = await c.req.json();
    const {
      ingredients,
      cuisines = [],
      servings = 2,
      language = "en",
      exactCount = 2,
      extraCount = 2,
      excludeTitles = [],
      deviceId,
    } = body;

    if (!deviceId || !ingredients || !Array.isArray(ingredients) || ingredients.length === 0) {
      return c.json({ error: "Missing required fields: deviceId, ingredients" }, 400);
    }
    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded. Please wait a moment." }, 429);
    }

    const systemPrompt = previewSystemPrompt(language, exactCount, extraCount, excludeTitles);
    const userPrompt = previewUserPrompt(ingredients, cuisines, servings, language, exactCount + extraCount, excludeTitles);

    console.log(`[PREVIEW] ${language} | ${exactCount}+${extraCount} | ${ingredients.join(", ")}`);

    const content = await callOpenAI(
      [{ role: "system", content: systemPrompt }, { role: "user", content: userPrompt }],
      0.85,
      Math.min(3000, Math.max(1200, (exactCount + extraCount) * 500)),
      true
    );

    if (!content) return c.json({ error: "No response from AI" }, 500);

    let parsed: any;
    try { parsed = JSON.parse(content); }
    catch { return c.json({ error: "Failed to parse AI response" }, 500); }

    const exactRecipes = (parsed.exact_match_recipes || []).slice(0, exactCount).map((r: any) => sanitizePreview(r, language));
    const extraRecipes = (parsed.extra_ingredient_recipes || []).slice(0, extraCount).map((r: any) => sanitizePreview(r, language));

    console.log(`[PREVIEW] ✅ ${exactRecipes.length} exact + ${extraRecipes.length} extra`);

    return c.json({ exact_match_recipes: exactRecipes, extra_ingredient_recipes: extraRecipes });

  } catch (err: any) {
    console.error("[PREVIEW] ❌", err.message);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

// ── Phase 2: Expand Recipes ───────────────────────────────────────────────────
// Client sends ONE recipe at a time. Backend returns steps + spices for it.
app.post("/expand-recipes", async (c) => {
  try {
    const body = await c.req.json();
    const { recipes, language = "en", deviceId } = body;

    if (!deviceId || !recipes || !Array.isArray(recipes) || recipes.length === 0) {
      return c.json({ error: "Missing required fields: deviceId, recipes" }, 400);
    }
    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded. Please wait a moment." }, 429);
    }

    const recipe = recipes[0]; // always 1 at a time
    console.log(`[EXPAND] "${recipe.title}" (${language})`);

    const systemPrompt = expandSystemPrompt(language);
    const userPrompt = expandUserPrompt([recipe], language);

    const content = await callOpenAI(
      [{ role: "system", content: systemPrompt }, { role: "user", content: userPrompt }],
      0.75,
      2000,
      true
    );

    if (!content) return c.json({ error: "No response from AI" }, 500);

    let parsed: any;
    try { parsed = JSON.parse(content); }
    catch { return c.json({ error: "Failed to parse AI response" }, 500); }

    const expanded = parsed.recipes || [];
    console.log(`[EXPAND] ✅ "${recipe.title}" done`);

    return c.json({ recipes: expanded });

  } catch (err: any) {
    console.error("[EXPAND] ❌", err.message);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

// ── Translate Recipes ─────────────────────────────────────────────────────────
app.post("/translate-recipes", async (c) => {
  try {
    const body = await c.req.json();
    const { recipes, targetLanguage, deviceId } = body;

    if (!deviceId || !recipes || !Array.isArray(recipes)) {
      return c.json({ error: "Missing required fields" }, 400);
    }
    if (!checkRateLimit(deviceId)) {
      return c.json({ error: "Rate limit exceeded." }, 429);
    }

    const targetLang = targetLanguage === "tr" ? "Turkish" : "English";
    const difficulty = targetLanguage === "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard";

    const systemPrompt = `You are a professional translator. Translate the following recipe JSON array to ${targetLang}.
Translate: title, description, cuisine, difficulty, ingredient names, ingredient units, steps, required_extra_ingredients, spice names and alternatives.
Keep: id, calories, servings, quantities.
Difficulty must be one of: ${difficulty}
Respond with ONLY the translated JSON array. No markdown.`;

    console.log(`[TRANSLATE] ${recipes.length} recipe(s) → ${targetLang}`);

    const content = await callOpenAI(
      [{ role: "system", content: systemPrompt }, { role: "user", content: JSON.stringify(recipes) }],
      0.3,
      8000,
      false
    );

    if (!content) return c.json({ error: "No response from AI" }, 500);

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
    try {
      const parsed = JSON.parse(cleaned);
      return c.json(parsed);
    } catch {
      return c.json({ error: "Failed to parse translation response" }, 500);
    }

  } catch (err: any) {
    console.error("[TRANSLATE] ❌", err.message);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ── Supabase: Recipe Reactions ─────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// GET /reactions/:userId/:recipeId
app.get("/reactions/:userId/:recipeId", async (c) => {
  try {
    const { userId, recipeId } = c.req.param();
    const data = await getRecipeReaction(userId, recipeId);
    return c.json({ reaction: data });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// POST /reactions/upsert  — body: { user_id, recipe_id, reaction }
app.post("/reactions/upsert", async (c) => {
  try {
    const body = await c.req.json();
    const { user_id, recipe_id, reaction } = body;

    if (!user_id || !recipe_id || !reaction) {
      return c.json({ error: "user_id, recipe_id, reaction required" }, 400);
    }
    if (!["like", "dislike", "save"].includes(reaction)) {
      return c.json({ error: "reaction must be like | dislike | save" }, 400);
    }

    const data = await upsertRecipeReaction({ user_id, recipe_id, reaction });
    return c.json({ ok: true, data });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// DELETE /reactions/:userId/:recipeId
app.delete("/reactions/:userId/:recipeId", async (c) => {
  try {
    const { userId, recipeId } = c.req.param();
    await deleteRecipeReaction(userId, recipeId);
    return c.json({ ok: true });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ── Supabase: Tried Recipes ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// GET /tried/:userId
app.get("/tried/:userId", async (c) => {
  try {
    const { userId } = c.req.param();
    const data = await getTriedRecipes(userId);
    return c.json({ tried: data });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// POST /tried  — body: { user_id, recipe_id, recipe_data }
app.post("/tried", async (c) => {
  try {
    const body = await c.req.json();
    const { user_id, recipe_id, recipe_data } = body;

    if (!user_id || !recipe_id) {
      return c.json({ error: "user_id and recipe_id required" }, 400);
    }

    const data = await markRecipeAsTried({ user_id, recipe_id, recipe_data: recipe_data || {} });
    return c.json({ ok: true, data });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
export default app;
