import { z } from "zod";
import OpenAI from "openai";
import { createTRPCRouter, publicProcedure } from "../create-context";
import {
  getCachedRecipesByIngredients,
  getPopularRecipes,
  saveRecipesToCache,
} from "../../lib/cache";
import { buildPreviewSystemPrompt, buildPreviewUserPrompt } from "../../lib/prompts";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY,
});

const PRIMARY_MODEL = "gpt-5-mini";
const FALLBACK_MODEL = "gpt-5.3-chat-latest";

function buildChatCompletionRequest(
  model: string,
  messages: Array<{ role: "system" | "user"; content: string }>,
  maxCompletionTokens: number,
  temperature?: number
) {
  const usesReasoningModel = model === PRIMARY_MODEL;
  return {
    model,
    messages,
    max_completion_tokens: maxCompletionTokens,
    ...(usesReasoningModel ? { reasoning_effort: "minimal" as const } : {}),
    ...(!usesReasoningModel && temperature !== undefined ? { temperature } : {}),
  };
}

async function createChatCompletion(
  messages: Array<{ role: "system" | "user"; content: string }>,
  maxCompletionTokens: number,
  temperature?: number,
  model = PRIMARY_MODEL
) {
  return openai.chat.completions.create(
    buildChatCompletionRequest(model, messages, maxCompletionTokens, temperature)
  );
}

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

      const totalNeeded = input.exactCount + input.extraCount;
      const maxCached = 2;

      let cachedRecipes: any[] = [];
      if (input.excludeTitles.length === 0) {
        cachedRecipes = await getCachedRecipesByIngredients(input.ingredients, maxCached, input.language);
      }

      const cachedCount = cachedRecipes.length;
      const usedCached = cachedRecipes.map((r: any) => ({ ...r, source: "cached" }));

      const aiTotal = totalNeeded - cachedCount;

      let aiExactNeeded: number;
      let aiExtraNeeded: number;

      if (cachedCount >= 2) {
        aiExactNeeded = Math.max(1, input.exactCount - 1);
        aiExtraNeeded = aiTotal - aiExactNeeded;
      } else if (cachedCount === 1) {
        aiExactNeeded = Math.max(1, input.exactCount - 1);
        aiExtraNeeded = aiTotal - aiExactNeeded;
      } else {
        aiExactNeeded = input.exactCount;
        aiExtraNeeded = input.extraCount;
      }

      if (aiExactNeeded < 0) aiExactNeeded = 0;
      if (aiExtraNeeded < 0) aiExtraNeeded = 0;

      const allExcludeTitles = [
        ...input.excludeTitles,
        ...usedCached.map((r: any) => r.title),
      ];

      const systemPrompt = buildPreviewSystemPrompt(input.language, aiExactNeeded, aiExtraNeeded, allExcludeTitles);
      const userPrompt = buildPreviewUserPrompt(
        input.ingredients, input.cuisines, input.servings, input.language,
        aiTotal, allExcludeTitles
      );

      const messages = [
        { role: "system" as const, content: systemPrompt },
        { role: "user" as const, content: userPrompt },
      ];

      let content: string | null | undefined

      try {
        const response = await createChatCompletion(messages, 4000, undefined, PRIMARY_MODEL);
        content = response.choices[0]?.message?.content;
      } catch {
        const fallbackResponse = await createChatCompletion(messages, 4000, 0.95, FALLBACK_MODEL);
        content = fallbackResponse.choices[0]?.message?.content;
      }
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

        const freshExact = (parsed.exact_match_recipes || [])
          .slice(0, aiExactNeeded)
          .map((r: any) => ({ ...r, source: "generated" }));
        const freshExtra = (parsed.extra_ingredient_recipes || [])
          .slice(0, aiExtraNeeded)
          .map((r: any) => ({ ...r, source: "generated" }));
        const allFresh = [...freshExact, ...freshExtra];

        let finalExact: any[] = [];
        let finalExtra: any[] = [];

        if (cachedCount >= 2) {
          finalExact = [usedCached[0], freshExact[0]].filter(Boolean).slice(0, input.exactCount);
          finalExtra = [usedCached[1], ...(freshExtra.length > 0 ? freshExtra : freshExact.slice(1))].filter(Boolean).slice(0, input.extraCount);
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

        if (cachedCount <= 1) {
          const allFinal = [...finalExact, ...finalExtra];
          const shuffled = [...allFinal].sort(() => Math.random() - 0.5);
          const toSave = shuffled.slice(0, 2);
          console.log('[TRPC] cachedCount=', cachedCount, '=> saving', toSave.length, 'to cache, language:', input.language);
          try {
            await saveRecipesToCache(toSave, input.language);
          } catch (err) {
            console.error('[TRPC] Cache save error:', err);
          }
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

      const targetLang = input.targetLanguage === "tr" ? "Turkish" : "English";

      const systemPrompt = `You are a translator. Translate the given recipe JSON array into ${targetLang}.
Translate ALL text fields: title, description, cuisine, difficulty, ingredient names, ingredient units, steps, required_extra_ingredients.
For the "spices" array: translate each spice "name" and all "alternatives" strings.
If "spices" field is missing but "spices_common" and "spices_optional" exist, translate those too.
Keep the same JSON structure. Keep id, calories, servings, and quantity values unchanged.
For difficulty, use: ${input.targetLanguage === "tr" ? "Kolay/Orta/Zor" : "Easy/Medium/Hard"}
Respond with ONLY the translated JSON array. No markdown, no extra text.`;

      const messages = [
        { role: "system" as const, content: systemPrompt },
        { role: "user" as const, content: JSON.stringify(input.recipes) },
      ];

      let content: string | null | undefined

      try {
        const response = await createChatCompletion(messages, 8000, undefined, PRIMARY_MODEL);
        content = response.choices[0]?.message?.content;
      } catch {
        const fallbackResponse = await createChatCompletion(messages, 8000, 0.3, FALLBACK_MODEL);
        content = fallbackResponse.choices[0]?.message?.content;
      }
      if (!content) {
        throw new Error("No response from AI");
      }

      const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

      try {
        return JSON.parse(cleaned);
      } catch {
        throw new Error("Failed to parse translation response");
      }
    }),
});
