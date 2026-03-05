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
    const maxCached = 3;

    let cachedRecipes: any[] = [];
    if (excludeTitles.length === 0) {
      cachedRecipes = await getCachedRecipesByIngredients(ingredients, maxCached, language);
    }

    const cachedCount = cachedRecipes.length;
    const usedCached = cachedRecipes.map((r: any) => ({ ...r, source: "cached" }));

    console.log('[GENERATE] Cache hit:', cachedCount, '/', maxCached);

    const aiTotal = Math.max(0, totalNeeded - cachedCount);

    if (aiTotal === 0) {
      const sanitizeRecipe = (r: any, src: string) => ({
        ...r,
        source: src,
        required_extra_ingredients: r.required_extra_ingredients || [],
        ingredients: (r.ingredients || []).map((i: any) => ({
          ...i,
          quantity: String(i.quantity ?? ""),
          unit: String(i.unit ?? "")
        })),
        spices: r.spices || [],
        servings: Number(r.servings || 2),
      });

      let finalExact: any[] = [];
      let finalExtra: any[] = [];
      const allCached = usedCached.map(r => sanitizeRecipe(r, "cached"));

      while (finalExact.length < exactCount && allCached.length > 0) {
        finalExact.push(allCached.shift());
      }
      while (finalExtra.length < extraCount && allCached.length > 0) {
        finalExtra.push(allCached.shift());
      }

      return c.json({
        exact_match_recipes: finalExact,
        extra_ingredient_recipes: finalExtra,
        _cache: { hit: true, cached_count: cachedCount, fresh_count: 0 },
      });
    }

    let aiExactNeeded = exactCount;
    let aiExtraNeeded = extraCount;

    for (let i = 0; i < cachedCount; i++) {
      if (aiExactNeeded >= aiExtraNeeded && aiExactNeeded > 0) {
        aiExactNeeded--;
      } else if (aiExtraNeeded > 0) {
        aiExtraNeeded--;
      } else if (aiExactNeeded > 0) {
        aiExactNeeded--;
      }
    }

    const allExcludeTitles = [
      ...excludeTitles,
      ...usedCached.map((r: any) => r.title),
    ];

    const systemPrompt = buildSystemPrompt(language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
    const userPrompt = buildUserPrompt(ingredients, cuisines || [], servings || 2, language, aiTotal, allExcludeTitles);

    console.log('[GENERATE] Requesting AI:', aiExactNeeded, 'exact +', aiExtraNeeded, 'extra');

    const aiRecipeCount = aiExactNeeded + aiExtraNeeded;
    const dynamicMaxTokens = Math.min(4000, Math.max(1500, aiRecipeCount * 1200));

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.8,
      max_tokens: Math.min(2500, dynamicMaxTokens),
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

      const sanitizeRecipe = (r: any, src: string) => ({
        ...r,
        source: src,
        required_extra_ingredients: r.required_extra_ingredients || [],
        ingredients: (r.ingredients || []).map((i: any) => ({
          ...i,
          quantity: String(i.quantity ?? ""),
          unit: String(i.unit ?? "")
        })),
        spices: r.spices || [],
        servings: Number(r.servings || 2),
      });

      const freshExactRaw = (parsed.exact_match_recipes || []).map((r: any) => sanitizeRecipe(r, "generated"));
      const freshExtraRaw = (parsed.extra_ingredient_recipes || []).map((r: any) => sanitizeRecipe(r, "generated"));
      const allFresh = [...freshExactRaw, ...freshExtraRaw];

      console.log('[GENERATE] AI returned:', freshExactRaw.length, 'exact +', freshExtraRaw.length, 'extra');

      let finalExact: any[] = [];
      let finalExtra: any[] = [];

      const allCached = usedCached.map(r => sanitizeRecipe(r, "cached"));

      while (finalExact.length < exactCount) {
        if (freshExactRaw.length > 0) {
          finalExact.push(freshExactRaw.shift());
        } else if (allCached.length > 0) {
          finalExact.push(allCached.shift());
        } else if (freshExtraRaw.length > 0) {
          finalExact.push(freshExtraRaw.shift());
        } else {
          break;
        }
      }

      while (finalExtra.length < extraCount) {
        if (freshExtraRaw.length > 0) {
          finalExtra.push(freshExtraRaw.shift());
        } else if (allCached.length > 0) {
          finalExtra.push(allCached.shift());
        } else if (freshExactRaw.length > 0) {
          finalExtra.push(freshExactRaw.shift());
        } else {
          break;
        }
      }

      const allFinal = [...finalExact, ...finalExtra];
      const newlyGenerated = allFinal.filter(r => r.source === "generated");

      if (newlyGenerated.length > 0) {
        const shuffled = [...newlyGenerated].sort(() => Math.random() - 0.5);
        const toSave = shuffled.slice(0, 2);
        console.log('[GENERATE] newly generated=', newlyGenerated.length, '=> saving', toSave.length, 'recipes to cache (non-blocking), language:', language);
        saveRecipesToCache(toSave, language).catch(err => console.error('[GENERATE] Cache save error:', err));
      } else {
        console.log('[GENERATE] newly generated=0 => skipping cache save');
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
    } catch (parseErr) {
      return c.json({ error: "Failed to parse AI response" }, 500);
    }
  } catch (err: any) {
    console.error('[GENERATE] Error:', err);
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

app.get("/test-cache-insert", async (c) => {
  try {
    const { supabase } = await import('./lib/supabase');

    const testRecipeId = `test_${Date.now()}`;
    const insertData = {
      recipe_id: testRecipeId,
      recipe_data: {
        id: testRecipeId,
        title: 'Test Recipe',
        calories: '200-300',
        cuisine: 'Test',
        difficulty: 'Easy',
        description: 'A test recipe',
        servings: 2,
        ingredients: [{ name: 'tomato', quantity: '2', unit: 'pieces' }],
        spices: [],
        required_extra_ingredients: [],
        steps: ['Step 1', 'Step 2'],
      },
    };

    console.log('[TEST] Inserting with new structure...');
    const { data, error } = await supabase.from('ai_cache').insert(insertData).select();

    if (error) {
      return c.json({
        status: 'failed',
        error: { message: error.message, code: error.code, hint: (error as any).hint, details: error.details },
      }, 500);
    }
    return c.json({ status: 'success', data });
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
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
    } catch (parseErr) {
      return c.json({ error: "Failed to parse translation response" }, 500);
    }
  } catch (err: any) {
    return c.json({ error: err.message || "Internal server error" }, 500);
  }
});

export default app;
