import { z } from "zod";
import OpenAI from "openai";
import { createTRPCRouter, publicProcedure } from "../create-context";
import {
  getCachedRecipesByIngredients,
  getPopularRecipes,
  saveRecipesToCache,
} from "../../lib/cache";
import { buildSystemPrompt, buildUserPrompt } from "../../lib/prompts";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY,
});

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

export const recipeRouter = createTRPCRouter({
  generate: publicProcedure
    .input(
      z.object({
        ingredients: z.array(z.string()),
        cuisines: z.array(z.string()),
        servings: z.number(),
        language: z.string().default("en"),
        exactCount: z.number().default(2),
        extraCount: z.number().default(2),
        excludeTitles: z.array(z.string()).default([]),
        deviceId: z.string(),
      })
    )
    .mutation(async ({ input }) => {
      if (!checkRateLimit(input.deviceId)) {
        throw new Error("Rate limit exceeded. Please wait a moment.");
      }

      const maxCached = 2;
      const cachedRecipes = input.excludeTitles.length === 0
        ? await getCachedRecipesByIngredients(input.ingredients, maxCached)
        : [];

      const cachedCount = Math.min(cachedRecipes.length, maxCached);
      const usedCached = cachedRecipes.slice(0, cachedCount).map((r: any) => ({ ...r, source: "cached" }));

      const aiNeeded = 4 - cachedCount;
      const aiExactNeeded = Math.max(1, input.exactCount - Math.min(cachedCount, 1));
      const aiExtraNeeded = aiNeeded - aiExactNeeded;

      const allExcludeTitles = [
        ...input.excludeTitles,
        ...usedCached.map((r: any) => r.title),
      ];

      const systemPrompt = buildSystemPrompt(input.language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
      const userPrompt = buildUserPrompt(
        input.ingredients, input.cuisines, input.servings, input.language,
        aiNeeded, allExcludeTitles
      );

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
          return {
            exact_match_recipes: usedCached.slice(0, input.exactCount),
            extra_ingredient_recipes: [],
            _cache: { hit: true, cached_count: cachedCount, fresh_count: 0 },
          };
        }
        throw new Error("No response from AI");
      }

      const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

      try {
        const parsed = JSON.parse(cleaned);

        const freshExact = (parsed.exact_match_recipes || []).slice(0, aiExactNeeded).map((r: any) => ({ ...r, source: "generated" }));
        const freshExtra = (parsed.extra_ingredient_recipes || []).slice(0, aiExtraNeeded).map((r: any) => ({ ...r, source: "generated" }));
        const allFresh = [...freshExact, ...freshExtra];

        let finalExact: any[] = [];
        let finalExtra: any[] = [];

        if (cachedCount >= 2) {
          finalExact = [usedCached[0], freshExact[0]].filter(Boolean).slice(0, input.exactCount);
          finalExtra = [usedCached[1], freshExtra[0] || freshExact[1]].filter(Boolean).slice(0, input.extraCount);
        } else if (cachedCount === 1) {
          finalExact = [usedCached[0], freshExact[0]].filter(Boolean).slice(0, input.exactCount);
          finalExtra = freshExtra.slice(0, input.extraCount);
          if (finalExtra.length < input.extraCount) {
            finalExtra = [...finalExtra, ...freshExact.slice(1)].slice(0, input.extraCount);
          }
        } else {
          finalExact = freshExact.slice(0, input.exactCount);
          finalExtra = freshExtra.slice(0, input.extraCount);
        }

        const recipesToCache = 2 - cachedCount;
        if (recipesToCache > 0 && allFresh.length > 0) {
          const shuffled = [...allFresh].sort(() => Math.random() - 0.5);
          const toSave = shuffled.slice(0, recipesToCache);
          saveRecipesToCache(toSave, input.ingredients).catch(err =>
            console.error('[CACHE] Background save failed:', err)
          );
        }

        return {
          exact_match_recipes: finalExact,
          extra_ingredient_recipes: finalExtra,
          _cache: {
            hit: cachedCount > 0,
            cached_count: cachedCount,
            fresh_count: allFresh.length,
          },
        };
      } catch {
        throw new Error("Failed to parse AI response");
      }
    }),

  popularRecipes: publicProcedure
    .input(
      z.object({
        language: z.string().default("en"),
        limit: z.number().default(10),
      })
    )
    .query(async ({ input }) => {
      const recipes = await getPopularRecipes(input.language, input.limit);
      return { recipes, count: recipes.length };
    }),

  translate: publicProcedure
    .input(
      z.object({
        recipes: z.array(z.any()),
        targetLanguage: z.string(),
        deviceId: z.string(),
      })
    )
    .mutation(async ({ input }) => {
      if (!checkRateLimit(input.deviceId)) {
        throw new Error("Rate limit exceeded. Please wait a moment.");
      }

      const targetLang =
        input.targetLanguage === "tr" ? "Turkish" : "English";

      const systemPrompt = `You are a translator. Translate the given recipe JSON array into ${targetLang}.
Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, ingredient units, steps, required_extra_ingredients.
For the "spices" array: translate each spice "name" and all "alternatives" strings.
If "spices" field is missing but "spices_common" and "spices_optional" exist, translate those too.
Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
For difficulty, use: ${input.targetLanguage === "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard"}
Respond with ONLY the translated JSON array. No markdown, no extra text.`;

      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: JSON.stringify(input.recipes) },
        ],
        temperature: 0.3,
        max_tokens: 8000,
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        throw new Error("No response from AI");
      }

      const cleaned = content
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();

      try {
        return JSON.parse(cleaned);
      } catch {
        throw new Error("Failed to parse translation response");
      }
    }),
});
