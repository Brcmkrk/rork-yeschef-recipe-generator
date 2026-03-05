import { Hono } from "hono";
import { cors } from "hono/cors";
import OpenAI from "openai";
import {
  buildPreviewSystemPrompt,
  buildPreviewUserPrompt,
  buildExpandSystemPrompt,
  buildExpandUserPrompt,
} from "./lib/prompts";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY,
});

const app = new Hono();

app.use("*", cors());

// ─── Rate Limiting ────────────────────────────────────────────────────────────
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

// ─── Health Check ────────────────────────────────────────────────────────────
app.get("/", (c) => {
  return c.json({ status: "ok", message: "YesChef API is running" });
});

// ─── Phase 1: Generate Previews ──────────────────────────────────────────────
// Returns title + description + ingredients only.
// Fast response (~5-8s). Steps and spices are empty arrays.
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

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.85,
      max_tokens: Math.min(1200, Math.max(600, (exactCount + extraCount) * 280)),
    });

    const content = response.choices[0]?.message?.content;
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
      steps: [],       // Empty — filled by expand endpoint
      spices: [],      // Empty — filled by expand endpoint
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

// ─── Phase 2: Expand Recipes ─────────────────────────────────────────────────
// Accepts 1 recipe at a time (called per-recipe from the client).
// Returns steps + spices for that recipe.
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

    const recipe = recipes[0]; // Process one at a time
    console.log(`[EXPAND] Expanding "${recipe.title}" (${language})`);

    const systemPrompt = buildExpandSystemPrompt(language);
    const userPrompt = buildExpandUserPrompt([recipe], language);

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.75,
      max_tokens: 1200,
    });

    const content = response.choices[0]?.message?.content;
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

// ─── Translate Recipes ────────────────────────────────────────────────────────
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

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: JSON.stringify(recipes) },
      ],
      temperature: 0.3,
      max_tokens: 8000,
    });

    const content = response.choices[0]?.message?.content;
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
