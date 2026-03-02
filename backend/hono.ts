import { Hono } from "hono";
import { cors } from "hono/cors";
import OpenAI from "openai";
import { buildSystemPrompt, buildUserPrompt } from "./lib/prompts";
import {
  getCachedRecipesByIngredients,
  getPopularRecipes,
  saveRecipesToCache,
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

    const totalNeeded = exactCount + extraCount;
    const maxCached = 2;

    let cachedRecipes: any[] = [];
    if (excludeTitles.length === 0) {
      cachedRecipes = await getCachedRecipesByIngredients(ingredients, maxCached);
    }

    const cachedCount = cachedRecipes.length;
    const usedCached = cachedRecipes.map((r: any) => ({ ...r, source: "cached" }));

    console.log('[GENERATE] Cache hit:', cachedCount, '/', maxCached);

    const aiTotal = totalNeeded - cachedCount;

    let aiExactNeeded: number;
    let aiExtraNeeded: number;

    if (cachedCount >= 2) {
      aiExactNeeded = Math.max(1, exactCount - 1);
      aiExtraNeeded = aiTotal - aiExactNeeded;
    } else if (cachedCount === 1) {
      aiExactNeeded = Math.max(1, exactCount - 1);
      aiExtraNeeded = aiTotal - aiExactNeeded;
    } else {
      aiExactNeeded = exactCount;
      aiExtraNeeded = extraCount;
    }

    if (aiExactNeeded < 0) aiExactNeeded = 0;
    if (aiExtraNeeded < 0) aiExtraNeeded = 0;

    const allExcludeTitles = [
      ...excludeTitles,
      ...usedCached.map((r: any) => r.title),
    ];

    const systemPrompt = buildSystemPrompt(language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
    const userPrompt = buildUserPrompt(ingredients, cuisines || [], servings || 2, language, aiTotal, allExcludeTitles);

    console.log('[GENERATE] Requesting AI:', aiExactNeeded, 'exact +', aiExtraNeeded, 'extra');

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
      if (usedCached.length > 0) {
        return c.json({
          exact_match_recipes: usedCached.slice(0, exactCount),
          extra_ingredient_recipes: [],
          _cache: { hit: true, cached_count: cachedCount, fresh_count: 0 },
        });
      }
      return c.json({ error: "No response from AI" }, 500);
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      const parsed = JSON.parse(cleaned);

      const freshExact = (parsed.exact_match_recipes || [])
        .slice(0, aiExactNeeded)
        .map((r: any) => ({ ...r, source: "generated" }));
      const freshExtra = (parsed.extra_ingredient_recipes || [])
        .slice(0, aiExtraNeeded)
        .map((r: any) => ({ ...r, source: "generated" }));
      const allFresh = [...freshExact, ...freshExtra];

      console.log('[GENERATE] AI returned:', freshExact.length, 'exact +', freshExtra.length, 'extra');

      let finalExact: any[] = [];
      let finalExtra: any[] = [];

      if (cachedCount >= 2) {
        finalExact = [usedCached[0], freshExact[0]].filter(Boolean).slice(0, exactCount);
        finalExtra = [usedCached[1], ...(freshExtra.length > 0 ? freshExtra : freshExact.slice(1))].filter(Boolean).slice(0, extraCount);
      } else if (cachedCount === 1) {
        finalExact = [usedCached[0], freshExact[0]].filter(Boolean).slice(0, exactCount);
        finalExtra = freshExtra.slice(0, extraCount);
        if (finalExtra.length < extraCount) {
          finalExtra = [...finalExtra, ...freshExact.slice(1)].slice(0, extraCount);
        }
      } else {
        finalExact = freshExact.slice(0, exactCount);
        finalExtra = freshExtra.slice(0, extraCount);
      }

      const recipesToCache = Math.min(2 - cachedCount, 2);
      if (recipesToCache > 0 && allFresh.length > 0) {
        const shuffled = [...allFresh].sort(() => Math.random() - 0.5);
        const toSave = shuffled.slice(0, recipesToCache);
        console.log('[GENERATE] Saving', toSave.length, 'recipes to cache:', toSave.map((r: any) => r.title));
        saveRecipesToCache(toSave, ingredients)
          .then(() => console.log('[GENERATE] Cache save done'))
          .catch(err => console.error('[GENERATE] Cache save error:', err));
      }

      return c.json({
        exact_match_recipes: finalExact,
        extra_ingredient_recipes: finalExtra,
        _cache: {
          hit: cachedCount > 0,
          cached_count: cachedCount,
          fresh_count: allFresh.length,
        },
      });
    } catch {
      return c.json({ error: "Failed to parse AI response" }, 500);
    }
  } catch (err: any) {
    console.error('[GENERATE] Error:', err);
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
