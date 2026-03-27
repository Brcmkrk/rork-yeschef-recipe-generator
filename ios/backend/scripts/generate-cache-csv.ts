import OpenAI from "openai";
import * as fs from "fs";

const openai = new OpenAI({
  apiKey: process.env.EXPO_PUBLIC_OPENAI_API_KEY || process.env.OPENAI_API_KEY,
});

const INGREDIENT_SETS = [
  ["chicken", "rice", "onion", "garlic"],
  ["pasta", "tomato", "garlic", "olive oil"],
  ["egg", "cheese", "butter", "milk"],
  ["beef", "potato", "carrot", "onion"],
  ["salmon", "lemon", "garlic", "butter"],
  ["shrimp", "garlic", "butter", "lemon"],
  ["chicken", "broccoli", "soy sauce", "garlic"],
  ["mushroom", "onion", "garlic", "butter"],
  ["tofu", "soy sauce", "garlic", "ginger"],
  ["lamb", "onion", "tomato", "garlic"],
  ["rice", "egg", "soy sauce", "onion"],
  ["potato", "cheese", "butter", "milk"],
  ["chicken", "cream", "mushroom", "garlic"],
  ["beef", "bell pepper", "onion", "soy sauce"],
  ["pasta", "cream", "garlic", "parmesan"],
  ["fish", "lemon", "olive oil", "garlic"],
  ["zucchini", "tomato", "onion", "garlic"],
  ["chicken", "honey", "soy sauce", "garlic"],
  ["egg", "tomato", "onion", "bell pepper"],
  ["rice", "chicken", "curry powder", "coconut milk"],
  ["avocado", "tomato", "onion", "lime"],
  ["spinach", "garlic", "cream", "parmesan"],
  ["pork", "apple", "onion", "garlic"],
  ["lentil", "onion", "tomato", "garlic"],
  ["cauliflower", "garlic", "butter", "cheese"],
  ["sweet potato", "onion", "garlic", "butter"],
  ["turkey", "rice", "onion", "bell pepper"],
  ["chickpea", "onion", "tomato", "garlic"],
  ["eggplant", "tomato", "onion", "garlic"],
  ["duck", "orange", "garlic", "butter"],
];

const CUISINES = [
  "Italian", "French", "Asian", "Mediterranean", "Mexican",
  "Japanese", "Indian", "American", "Thai", "Middle Eastern",
  "Korean", "Greek", "Spanish", "Turkish", "Vietnamese",
];

function getSystemPrompt(count: number): string {
  return `You are a professional chef and recipe creator. You MUST respond with ONLY a valid JSON array, no markdown, no extra text, no explanation.

Each recipe object in the array must follow this schema exactly:
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
    {"name": "black pepper", "alternatives": ["white pepper", "green peppercorn"]}
  ],
  "required_extra_ingredients": [],
  "steps": [
    "Detailed step with timing, temperature, and quantities..."
  ]
}

Rules:
- Return exactly ${count} recipes as a JSON array
- Give each recipe a unique and creative name
- All quantities MUST be scaled to the requested servings number
- STEPS MUST BE VERY DETAILED: precise timing, temperature, quantities, and visual cues
- Each recipe must have 5-8 clear, detailed steps
- Make recipes realistic, diverse, and cookable
- No duplicate or near-duplicate recipes
- In "spices" array, list ALL spices used. Each spice must have 2-3 alternatives
- IMPORTANT INGREDIENT CONSISTENCY: Every ingredient in steps MUST appear in "ingredients" list
- Everything must be in English
- required_extra_ingredients should be empty array []
- Vary cuisines and cooking methods`;
}

function getUserPrompt(ingredients: string[], servings: number, count: number, excludeTitles: string[]): string {
  let exclude = "";
  if (excludeTitles.length > 0) {
    exclude = `\n\nDo NOT repeat these recipes, generate completely different ones: ${excludeTitles.join(", ")}`;
  }
  const cuisine = CUISINES[Math.floor(Math.random() * CUISINES.length)];
  return `Generate ${count} recipes using these ingredients: ${ingredients.join(", ")}

Suggested cuisine style (but vary): ${cuisine}
Servings: ${servings}

Return ONLY a valid JSON array. No markdown.${exclude}`;
}

interface Recipe {
  id: string;
  title: string;
  calories: string;
  cuisine: string;
  difficulty: string;
  description: string;
  servings: number;
  ingredients: any[];
  spices: any[];
  required_extra_ingredients: string[];
  steps: string[];
}

function escapeCSV(str: string): string {
  const s = str.replace(/"/g, '""');
  return `"${s}"`;
}

async function generateBatch(ingredients: string[], servings: number, count: number, excludeTitles: string[]): Promise<Recipe[]> {
  const systemPrompt = getSystemPrompt(count);
  const userPrompt = getUserPrompt(ingredients, servings, count, excludeTitles);

  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    temperature: 0.95,
    max_tokens: 8000,
  });

  const content = response.choices[0]?.message?.content;
  if (!content) throw new Error("No response from AI");

  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  const parsed = JSON.parse(cleaned);

  const recipes: Recipe[] = Array.isArray(parsed) ? parsed : (parsed.exact_match_recipes || parsed.recipes || []);
  return recipes.map((r: any) => ({
    ...r,
    servings,
    required_extra_ingredients: r.required_extra_ingredients || [],
  }));
}

async function main() {
  const allRecipes: { recipe_id: string; recipe_data: Recipe }[] = [];
  const allTitles: string[] = [];
  let counter = 1;

  for (let servings = 1; servings <= 6; servings++) {
    console.log(`\n=== Generating recipes for ${servings} servings ===`);
    let generated = 0;
    let attempts = 0;

    while (generated < 20 && attempts < 10) {
      const remaining = 20 - generated;
      const batchSize = Math.min(remaining, 5);
      const ingredientSet = INGREDIENT_SETS[(generated + servings * 5) % INGREDIENT_SETS.length];

      console.log(`  Batch: ${batchSize} recipes with [${ingredientSet.join(", ")}] (attempt ${attempts + 1})`);

      try {
        const recipes = await generateBatch(ingredientSet, servings, batchSize, allTitles.slice(-30));

        for (const recipe of recipes) {
          if (generated >= 20) break;

          const recipeId = `cache_seed_${String(counter).padStart(3, "0")}`;
          recipe.id = recipeId;

          allRecipes.push({ recipe_id: recipeId, recipe_data: recipe });
          allTitles.push(recipe.title);
          generated++;
          counter++;
          console.log(`    [${counter - 1}] ${recipe.title} (${servings} servings)`);
        }
      } catch (err: any) {
        console.error(`    ERROR: ${err.message}`);
      }

      attempts++;
      await new Promise((r) => setTimeout(r, 1500));
    }

    console.log(`  => ${generated}/20 recipes generated for ${servings} servings`);
  }

  const header = "recipe_id,recipe_data";
  const rows = allRecipes.map((r) => {
    const jsonStr = JSON.stringify(r.recipe_data);
    return `${r.recipe_id},${escapeCSV(jsonStr)}`;
  });

  const csv = [header, ...rows].join("\n");
  fs.writeFileSync("backend/data/ai_cache_seed_120.csv", csv, "utf-8");
  console.log(`\nDone! Generated ${allRecipes.length} recipes -> backend/data/ai_cache_seed_120.csv`);
}

main().catch(console.error);
