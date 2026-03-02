import { z } from "zod";
import OpenAI from "openai";
import { createTRPCRouter, publicProcedure } from "../create-context";
import {
  getCachedRecipesByIngredients,
  getPopularRecipes,
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

      const cachedRecipes = input.excludeTitles.length === 0
        ? await getCachedRecipesByIngredients(input.ingredients, 2)
        : [];

      const cachedExact = cachedRecipes.slice(0, 1);
      const cachedExtra = cachedRecipes.slice(1, 2);

      const aiExactNeeded = input.exactCount - cachedExact.length;
      const aiExtraNeeded = input.extraCount - cachedExtra.length;
      const aiTotal = aiExactNeeded + aiExtraNeeded;

      const allExcludeTitles = [
        ...input.excludeTitles,
        ...cachedExact.map((r: any) => r.title),
        ...cachedExtra.map((r: any) => r.title),
      ];

      if (aiTotal <= 0) {
        return {
          exact_match_recipes: cachedExact.slice(0, input.exactCount),
          extra_ingredient_recipes: cachedExtra.slice(0, input.extraCount),
          _cache: { hit: true, cached_count: cachedExact.length + cachedExtra.length, fresh_count: 0 },
        };
      }

      const systemPrompt = buildSystemPrompt(input.language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
      const userPrompt = buildUserPrompt(
        input.ingredients, input.cuisines, input.servings, input.language,
        aiTotal, allExcludeTitles
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
        if (cachedRecipes.length > 0) {
          return {
            exact_match_recipes: cachedExact,
            extra_ingredient_recipes: cachedExtra,
            _cache: { hit: true, cached_count: cachedRecipes.length, fresh_count: 0 },
          };
        }
        throw new Error("No response from AI");
      }

      const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

      try {
        const parsed = JSON.parse(cleaned);

        const freshExact = (parsed.exact_match_recipes || []).slice(0, aiExactNeeded);
        const freshExtra = (parsed.extra_ingredient_recipes || []).slice(0, aiExtraNeeded);

        const finalExact = [...cachedExact, ...freshExact].slice(0, input.exactCount);
        const finalExtra = [...cachedExtra, ...freshExtra].slice(0, input.extraCount);

        return {
          exact_match_recipes: finalExact,
          extra_ingredient_recipes: finalExtra,
          _cache: {
            hit: cachedRecipes.length > 0,
            cached_count: cachedExact.length + cachedExtra.length,
            fresh_count: freshExact.length + freshExtra.length,
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
