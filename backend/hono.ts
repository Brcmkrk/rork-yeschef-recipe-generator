import { Hono } from "hono";
import { cors } from "hono/cors";
import OpenAI from "openai";
import { buildSystemPrompt, buildUserPrompt } from "./lib/prompts";
import {
  getCachedRecipesByIngredients,
  getPopularRecipes,
} from "./lib/cache";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY,
});

const app = new Hono();

app.use("*", cors());

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 10;
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

app.get("/", (c) => {
  return c.json({ status: "ok", message: "YesChef API is running" });
});

app.post("/generate-recipe", async (c) => {
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

    const cachedRecipes = excludeTitles.length === 0
      ? await getCachedRecipesByIngredients(ingredients, 2)
      : [];

    const cachedExact = cachedRecipes.slice(0, 1);
    const cachedExtra = cachedRecipes.slice(1, 2);

    const aiExactNeeded = exactCount - cachedExact.length;
    const aiExtraNeeded = extraCount - cachedExtra.length;
    const aiTotal = aiExactNeeded + aiExtraNeeded;

    const cachedTitles = [...cachedExact, ...cachedExtra, ...excludeTitles.map((t: string) => t)];
    const allExcludeTitles = [
      ...excludeTitles,
      ...cachedExact.map((r: any) => r.title),
      ...cachedExtra.map((r: any) => r.title),
    ];

    if (aiTotal <= 0) {
      return c.json({
        exact_match_recipes: cachedExact.slice(0, exactCount),
        extra_ingredient_recipes: cachedExtra.slice(0, extraCount),
        _cache: { hit: true, cached_count: cachedExact.length + cachedExtra.length, fresh_count: 0 },
      });
    }

    const systemPrompt = buildSystemPrompt(language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
    const userPrompt = buildUserPrompt(ingredients, cuisines || [], servings || 2, language, aiTotal, allExcludeTitles);

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.95,
      max_tokens: 4000,
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      if (cachedRecipes.length > 0) {
        return c.json({
          exact_match_recipes: cachedExact,
          extra_ingredient_recipes: cachedExtra,
          _cache: { hit: true, cached_count: cachedRecipes.length, fresh_count: 0 },
        });
      }
      return c.json({ error: "No response from AI" }, 500);
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      const parsed = JSON.parse(cleaned);

      const freshExact = (parsed.exact_match_recipes || []).slice(0, aiExactNeeded);
      const freshExtra = (parsed.extra_ingredient_recipes || []).slice(0, aiExtraNeeded);

      const finalExact = [...cachedExact, ...freshExact].slice(0, exactCount);
      const finalExtra = [...cachedExtra, ...freshExtra].slice(0, extraCount);

      return c.json({
        exact_match_recipes: finalExact,
        extra_ingredient_recipes: finalExtra,
        _cache: {
          hit: cachedRecipes.length > 0,
          cached_count: cachedExact.length + cachedExtra.length,
          fresh_count: freshExact.length + freshExtra.length,
        },
      });
    } catch {
      return c.json({ error: "Failed to parse AI response" }, 500);
    }
  } catch (err: any) {
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

app.get("/popular-recipes", async (c) => {
  try {
    const language = c.req.query("language") || "en";
    const limit = parseInt(c.req.query("limit") || "10");
    const recipes = await getPopularRecipes(language, limit);
    return c.json({ recipes, count: recipes.length });
  } catch (err: any) {
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
If "spices" field is missing but "spices_common" and "spices_optional" exist, translate those too.
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
