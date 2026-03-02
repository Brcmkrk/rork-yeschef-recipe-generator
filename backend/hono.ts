import { Hono } from "hono";
import { cors } from "hono/cors";
import OpenAI from "openai";
import { buildSystemPrompt, buildUserPrompt } from "./lib/prompts";
import {
  generateCacheKey,
  generateIngredientsKey,
  getPartialCachedRecipes,
  storeCacheEntry,
  getPopularRecipes,
  cleanExpiredCache,
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

    const cacheKey = generateCacheKey(ingredients, cuisines || [], servings || 2, language);
    const ingredientsKey = generateIngredientsKey(ingredients);

    if (excludeTitles.length === 0) {
      const cachedPartial = await getPartialCachedRecipes(
        cacheKey,
        ingredientsKey,
        language,
        exactCount,
        extraCount
      );

      if (cachedPartial) {
        const cachedExact = cachedPartial.exact;
        const cachedExtra = cachedPartial.extra;

        const cacheExactToUse = cachedExact.slice(0, 1);
        const cacheExtraToUse = cachedExtra.slice(0, 1);
        const cachedTitles = [...cacheExactToUse, ...cacheExtraToUse].map(r => r.title);

        const aiExactNeeded = exactCount - cacheExactToUse.length;
        const aiExtraNeeded = extraCount - cacheExtraToUse.length;

        const systemPrompt = buildSystemPrompt(language, aiExactNeeded, aiExtraNeeded, cachedTitles);
        const userPrompt = buildUserPrompt(ingredients, cuisines || [], servings || 2, language, aiExactNeeded + aiExtraNeeded, cachedTitles);

        try {
          const aiResult = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userPrompt },
            ],
            temperature: 0.95,
            max_tokens: 4000,
          });

          const content = aiResult.choices[0]?.message?.content;
          if (content) {
            const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
            const freshParsed = JSON.parse(cleaned);

            const freshExact = (freshParsed.exact_match_recipes || []).slice(0, aiExactNeeded);
            const freshExtra = (freshParsed.extra_ingredient_recipes || []).slice(0, aiExtraNeeded);

            const mixedExact = [...cacheExactToUse, ...freshExact].slice(0, exactCount);
            const mixedExtra = [...cacheExtraToUse, ...freshExtra].slice(0, extraCount);

            storeCacheEntry(cacheKey, ingredientsKey, language, {
              exact_match_recipes: [...cachedExact, ...freshExact],
              extra_ingredient_recipes: [...cachedExtra, ...freshExtra],
            }).catch((err) => console.error("[CACHE STORE ERROR]", err));

            return c.json({
              exact_match_recipes: mixedExact,
              extra_ingredient_recipes: mixedExtra,
              _cache: { hit: true, cached_count: cacheExactToUse.length + cacheExtraToUse.length, fresh_count: freshExact.length + freshExtra.length },
            });
          }
        } catch {
          // AI failed, fall through to full generation
        }
      }
    }

    const totalCount = exactCount + extraCount;
    const systemPrompt = buildSystemPrompt(language, exactCount, extraCount, excludeTitles);
    const userPrompt = buildUserPrompt(ingredients, cuisines || [], servings || 2, language, totalCount, excludeTitles);

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.9,
      max_tokens: 5000,
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      return c.json({ error: "No response from AI" }, 500);
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      const parsed = JSON.parse(cleaned);

      if (excludeTitles.length === 0) {
        storeCacheEntry(cacheKey, ingredientsKey, language, parsed).catch((err) => console.error("[CACHE STORE ERROR]", err));
      }

      parsed._cache = { hit: false, cached_count: 0 };
      return c.json(parsed);
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

app.post("/cache/cleanup", async (c) => {
  try {
    const removed = await cleanExpiredCache();
    return c.json({ removed, status: "ok" });
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
