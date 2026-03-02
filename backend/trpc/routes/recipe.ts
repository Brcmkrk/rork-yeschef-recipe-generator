import { z } from "zod";
import OpenAI from "openai";
import { createTRPCRouter, publicProcedure } from "../create-context";
import {
  generateCacheKey,
  generateIngredientsKey,
  getPartialCachedRecipes,
  storeCacheEntry,
  getPopularRecipes,
  cleanExpiredCache,
} from "../../lib/cache";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY,
});

function buildSystemPrompt(
  language: string,
  exactCount: number,
  extraCount: number,
  excludeTitles: string[]
): string {
  const isTurkish = language === "tr";

  if (isTurkish) {
    return `Sen profesyonel bir şef ve tarif oluşturucusun. SADECE geçerli JSON ile yanıt vermelisin, markdown yok, ekstra metin yok, açıklama yok.

TÜMÜ Türkçe olmalı — tarif başlıkları, açıklamalar, malzeme adları, birim adları, baharat adları, adımlar, zorluk seviyesi, mutfak adı — HER ŞEY TÜRKÇE.

Tam olarak uyman gereken JSON şeması:
{
  "exact_match_recipes": [
    {
      "id": "unique_string",
      "title": "Tarif Başlığı",
      "calories": "300-400",
      "cuisine": "İtalyan",
      "difficulty": "Kolay|Orta|Zor",
      "description": "Kısa 1-2 cümlelik açıklama",
      "servings": 2,
      "ingredients": [{"name": "tavuk", "quantity": "500", "unit": "g"}],
      "spices": [
        {"name": "tuz", "alternatives": ["deniz tuzu", "himalaya tuzu"]},
        {"name": "karabiber", "alternatives": ["beyaz biber", "yeşil biber"]},
        {"name": "kimyon", "alternatives": ["kişniş", "rezene"]}
      ],
      "required_extra_ingredients": [],
      "steps": [
        "Tavuğu küçük parçalara kesin ve orta ateşte 2 yemek kaşığı zeytinyağında 8-10 dakika, her tarafı altın rengi olana kadar kavurun.",
        "Soğanları ince ince doğrayın ve aynı tavada 3-4 dakika, şeffaflaşana kadar soteleyin."
      ]
    }
  ],
  "extra_ingredient_recipes": [aynı yapı]
}

Kurallar:
- Her tarife benzersiz ve yaratıcı bir isim ver. Sıradan veya genel isimler KULLANMA.
- Tam olarak ${exactCount} exact_match_recipes ve ${extraCount} extra_ingredient_recipes döndür
- exact_match_recipes SADECE kullanıcının malzemelerini ve temel mutfak malzemelerini (su, tuz, karabiber, yağ, tereyağı) kullanır. exact_match_recipes için required_extra_ingredients boş dizi [] olmalı.
- ÖNEMLİ: extra_ingredient_recipes kullanıcının malzemelerini ARTI required_extra_ingredients'te listelenen 2-4 ek malzeme kullanır. required_extra_ingredients ASLA BOŞ OLMAMALI, her extra_ingredient tarifinde mutlaka 2-4 ek malzeme olmalı (örn: ["krema", "mantar", "parmesan"])
- extra_ingredient_recipes'teki ek malzemeler kullanıcının vermediği yeni malzemeler olmalı
- Tüm miktarları istenen porsiyona göre ayarla
- ADIMLAR ÇOK DETAYLI OLMALI: Her adımda kesin süre belirt (örn. "5 dakika pişirin", "20 dakika fırınlayın", "3-4 dakika kavurun"), sıcaklık derecesi (örn. "180°C fırında", "orta ateşte"), miktar (örn. "2 yemek kaşığı yağ ekleyin"), ve görsel ipuçları (örn. "altın rengi olana kadar", "kaynamaya başlayana kadar") ver. Kısa ve belirsiz adımlar YAZMA.
- Her tarifin 5-8 açık, detaylı adımı olsun
- Tarifler gerçekçi, çeşitli ve yapılabilir olsun
- Tekrar eden veya birbirine çok benzer tarifler olmasın
- "spices" dizisinde tarifin kullandığı TÜM baharatları listele. Her baharatın 2-3 alternatifi olsun (yerine kullanılabilecek baharatlar).
- ÖNEMLİ MALZEME TUTARLILIĞI: Adımlarda kullanılan HER malzeme mutlaka "ingredients" veya "required_extra_ingredients" listesinde yer almalı. Örneğin adımlarda "yufka açın" yazıyorsa, yufka mutlaka malzeme listesinde olmalı. Tarifi oluşturduktan sonra adımları tekrar kontrol et ve eksik malzeme varsa ekle. Baharatlar hariç hiçbir malzeme atlanmamalı.
- HER ŞEY TÜRKÇE OLMALI — İngilizce tek bir kelime bile olmamalı${
      excludeTitles.length > 0
        ? `\n- ÇOK ÖNEMLİ YASAK LİSTESİ: Aşağıdaki tarifleri KESİNLİKLE TEKRAR VERME. Bu isimlere benzer tarifler de VERME. Tamamen farklı yemek türleri ve pişirme yöntemleri kullan:\n${excludeTitles.map((t) => `  * ${t}`).join("\n")}`
        : ""
    }`;
  } else {
    return `You are a professional chef and recipe creator. You MUST respond with ONLY valid JSON, no markdown, no extra text, no explanation.

The JSON schema you must follow exactly:
{
  "exact_match_recipes": [
    {
      "id": "unique_string",
      "title": "Recipe Title",
      "calories": "300-400",
      "cuisine": "Italian",
      "difficulty": "Easy|Medium|Hard",
      "description": "Short 1-2 sentence description",
      "servings": 2,
      "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
      "spices": [
        {"name": "salt", "alternatives": ["sea salt", "pink salt"]},
        {"name": "black pepper", "alternatives": ["white pepper", "green peppercorn"]},
        {"name": "cumin", "alternatives": ["coriander", "caraway"]}
      ],
      "required_extra_ingredients": [],
      "steps": [
        "Cut the chicken into bite-sized pieces and sear in 2 tablespoons of olive oil over medium-high heat for 8-10 minutes, turning occasionally, until golden brown on all sides.",
        "Dice the onions finely and sauté in the same pan for 3-4 minutes until translucent and fragrant."
      ]
    }
  ],
  "extra_ingredient_recipes": [same structure]
}

Rules:
- Give each recipe a unique and creative name. Do NOT use generic or common names.
- Return exactly ${exactCount} exact_match_recipes and ${extraCount} extra_ingredient_recipes
- exact_match_recipes use ONLY the user's ingredients plus basic pantry items (water, salt, pepper, oil, butter). required_extra_ingredients must be an empty array [] for these.
- IMPORTANT: extra_ingredient_recipes use the user's ingredients PLUS 2-4 additional ingredients listed in required_extra_ingredients. required_extra_ingredients must NEVER be empty for these recipes - always include 2-4 extra ingredients the user didn't provide (e.g. ["cream", "mushrooms", "parmesan"])
- The extra ingredients should be ingredients NOT in the user's list
- Scale all quantities to the requested servings
- STEPS MUST BE VERY DETAILED: Every step must include precise timing (e.g. "cook for 5 minutes", "bake for 20 minutes at 180°C"), temperature (e.g. "over medium-high heat", "preheat oven to 200°C"), quantities (e.g. "add 2 tablespoons of oil"), and visual cues (e.g. "until golden brown", "until the sauce thickens"). Do NOT write short vague steps.
- Each recipe must have 5-8 clear, detailed steps
- Make recipes realistic, diverse, and cookable
- No duplicate or near-duplicate recipes
- In "spices" array, list ALL spices the recipe uses. Each spice must have 2-3 alternatives (substitutes that can replace it).
- IMPORTANT INGREDIENT CONSISTENCY: Every ingredient used in the steps MUST appear in the "ingredients" or "required_extra_ingredients" list. For example, if a step says "roll out the phyllo dough", then phyllo dough MUST be in the ingredients list. After generating the recipe, review all steps and ensure no ingredient is missing from the lists. Spices are excluded from this rule.
- Everything must be in English${
      excludeTitles.length > 0
        ? `\n- CRITICAL BANNED LIST: You MUST NOT repeat ANY of the following recipes. Do NOT generate anything similar to them either. Use completely different dish types and cooking methods:\n${excludeTitles.map((t) => `  * ${t}`).join("\n")}`
        : ""
    }`;
  }
}

function buildUserPrompt(
  ingredients: string[],
  cuisines: string[],
  servings: number,
  language: string,
  totalCount: number,
  excludeTitles: string[]
): string {
  const ingredientList = ingredients.join(", ");
  const cuisineList =
    cuisines.length === 0
      ? language === "tr"
        ? "Herhangi bir mutfak"
        : "Any cuisine"
      : cuisines.join(", ");

  let excludeNote = "";
  if (excludeTitles.length > 0) {
    const titles = excludeTitles.join(", ");
    excludeNote =
      language === "tr"
        ? `\n\nÖNEMLİ: Şu tarifleri TEKRAR VERME, tamamen farklı tarifler oluştur: ${titles}`
        : `\n\nIMPORTANT: Do NOT repeat these recipes, generate completely different ones: ${titles}`;
  }

  if (language === "tr") {
    return `Bu malzemeleri kullanarak ${totalCount} tarif oluştur: ${ingredientList}

Mutfak tercihleri: ${cuisineList}
Porsiyon: ${servings}

Hatırla: SADECE geçerli JSON döndür. Markdown formatı yok. HER ŞEY TÜRKÇE OLMALI — baharat isimleri, adımlar, malzeme isimleri, birimler dahil tamamı Türkçe.${excludeNote}`;
  } else {
    return `Generate ${totalCount} recipes using these ingredients: ${ingredientList}

Cuisine preferences: ${cuisineList}
Servings: ${servings}

Remember: Return ONLY valid JSON matching the exact schema. No markdown formatting. All content in English.${excludeNote}`;
  }
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

      const cacheKey = generateCacheKey(input.ingredients, input.cuisines, input.servings, input.language);
      const ingredientsKey = generateIngredientsKey(input.ingredients);

      if (input.excludeTitles.length === 0) {
        const cachedPartial = await getPartialCachedRecipes(
          cacheKey,
          ingredientsKey,
          input.language,
          input.exactCount,
          input.extraCount
        );

        if (cachedPartial) {
          const cachedExact = cachedPartial.exact;
          const cachedExtra = cachedPartial.extra;

          const cacheExactToUse = cachedExact.slice(0, 1);
          const cacheExtraToUse = cachedExtra.slice(0, 1);
          const cachedTitles = [...cacheExactToUse, ...cacheExtraToUse].map((r: any) => r.title);

          const aiExactNeeded = input.exactCount - cacheExactToUse.length;
          const aiExtraNeeded = input.extraCount - cacheExtraToUse.length;

          const systemPrompt = buildSystemPrompt(input.language, aiExactNeeded, aiExtraNeeded, cachedTitles);
          const userPrompt = buildUserPrompt(
            input.ingredients, input.cuisines, input.servings, input.language,
            aiExactNeeded + aiExtraNeeded, cachedTitles
          );

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

              const mixedExact = [...cacheExactToUse, ...freshExact].slice(0, input.exactCount);
              const mixedExtra = [...cacheExtraToUse, ...freshExtra].slice(0, input.extraCount);

              storeCacheEntry(cacheKey, ingredientsKey, input.language, {
                exact_match_recipes: [...cachedExact, ...freshExact],
                extra_ingredient_recipes: [...cachedExtra, ...freshExtra],
              }).catch(() => {});

              return {
                exact_match_recipes: mixedExact,
                extra_ingredient_recipes: mixedExtra,
                _cache: { hit: true, cached_count: cacheExactToUse.length + cacheExtraToUse.length, fresh_count: freshExact.length + freshExtra.length },
              };
            }
          } catch {
            // AI failed, fall through to full AI generation
          }
        }
      }

      const totalCount = input.exactCount + input.extraCount;
      const systemPrompt = buildSystemPrompt(
        input.language,
        input.exactCount,
        input.extraCount,
        input.excludeTitles
      );
      const userPrompt = buildUserPrompt(
        input.ingredients,
        input.cuisines,
        input.servings,
        input.language,
        totalCount,
        input.excludeTitles
      );

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
        throw new Error("No response from AI");
      }

      const cleaned = content
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();

      try {
        const parsed = JSON.parse(cleaned);

        if (input.excludeTitles.length === 0) {
          storeCacheEntry(cacheKey, ingredientsKey, input.language, parsed).catch(() => {});
        }

        parsed._cache = { hit: false, cached_count: 0 };
        return parsed;
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

  cleanupCache: publicProcedure.mutation(async () => {
    const removed = await cleanExpiredCache();
    return { removed, status: "ok" };
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
