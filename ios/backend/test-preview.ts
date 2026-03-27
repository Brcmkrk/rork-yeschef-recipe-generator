/**
 * End-to-end test: calls /generate-recipe-previews and shows the raw response.
 * Run with: npx tsx test-preview.ts
 */

import * as fs from "fs";
import * as path from "path";

// Load .env.local manually
const envPath = path.join(process.cwd(), ".env.local");
const envText = fs.readFileSync(envPath, "utf8");
for (const line of envText.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx < 0) continue;
    const key = trimmed.slice(0, idx).trim();
    const val = trimmed.slice(idx + 1).trim();
    process.env[key] = val;
}

const OPENAI_KEY = process.env.OPENAI_API_KEY || process.env.EXPO_PUBLIC_OPENAI_API_KEY || "";
console.log("OpenAI key loaded:", OPENAI_KEY ? OPENAI_KEY.slice(0, 10) + "..." : "MISSING!");

// ── Test 1: Call OpenAI directly to check the raw JSON structure ─────────────
async function testDirectOpenAI() {
    console.log("\n========== TEST 1: RAW OPENAI RESPONSE ==========");
    const systemPrompt = `You are a professional chef. Return ONLY valid JSON.

THIS IS A PREVIEW REQUEST — Do NOT include "steps" or "spices" fields.

Return this JSON structure:
{
  "exact_match_recipes": [{
    "id": "unique_id",
    "title": "Recipe Name",
    "calories": "300-400",
    "cuisine": "Italian",
    "difficulty": "Easy",
    "description": "Short 1-2 sentence description.",
    "servings": 2,
    "ingredients": [{"name": "chicken", "quantity": "500", "unit": "g"}],
    "required_extra_ingredients": []
  }],
  "extra_ingredient_recipes": [same structure]
}

Rules:
- Return EXACTLY 2 exact_match_recipes and 2 extra_ingredient_recipes
- exact_match: user's ingredients + basic pantry only. required_extra_ingredients = []
- extra_ingredient: user ingredients + 2-4 NEW ingredients in required_extra_ingredients
- All content in English`;

    const userPrompt = `Create 4 recipes using: chicken, onion, garlic
Cuisine: Any | Servings: 2
Return ONLY JSON. All English.`;

    const body = {
        model: "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt }
        ],
        temperature: 0.85,
        max_tokens: 2000,
    };

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${OPENAI_KEY}`,
        },
        body: JSON.stringify(body),
    });

    console.log("HTTP Status:", resp.status);
    const data: any = await resp.json();

    if (!resp.ok) {
        console.error("OpenAI error:", JSON.stringify(data, null, 2));
        return;
    }

    const content = data.choices?.[0]?.message?.content;
    console.log("\n--- RAW CONTENT (first 1000 chars) ---");
    console.log(content?.slice(0, 1000));

    // Try parsing
    try {
        const parsed = JSON.parse(content);
        console.log("\n--- PARSED KEYS ---", Object.keys(parsed));
        const exactRecipes = parsed.exact_match_recipes || [];
        const extraRecipes = parsed.extra_ingredient_recipes || [];
        console.log(`exact_match_recipes: ${exactRecipes.length} recipes`);
        console.log(`extra_ingredient_recipes: ${extraRecipes.length} recipes`);
        if (exactRecipes[0]) {
            console.log("\nFirst recipe keys:", Object.keys(exactRecipes[0]));
            console.log("First recipe:", JSON.stringify(exactRecipes[0], null, 2));
        }

        // ── Now try to simulate Swift's RecipeResponse decode ──────────────────
        // Swift Recipe struct needs: id, title, calories, cuisine, difficulty,
        // description, servings, ingredients[], spices?, spices_common?,
        // spices_optional?, required_extra_ingredients[], steps[], language?, source?, isExpanded?
        const REQUIRED_FIELDS = ["id", "title", "calories", "cuisine", "difficulty", "description", "servings", "ingredients", "required_extra_ingredients", "steps"];

        console.log("\n--- CHECKING REQUIRED FIELDS ---");
        for (const recipe of [...exactRecipes, ...extraRecipes]) {
            for (const field of REQUIRED_FIELDS) {
                if (recipe[field] === undefined) {
                    console.error(`❌ MISSING FIELD: "${field}" in recipe "${recipe.title}"`);
                }
            }
        }
        console.log("✅ Field check complete");

    } catch (e) {
        console.error("❌ JSON PARSE FAILED:", e);
    }
}

// ── Test 2: Simulate sanitizePreview output and check it decodes ─────────────
async function testSanitizeOutput() {
    console.log("\n========== TEST 2: SANITIZE OUTPUT STRUCTURE ==========");
    // Simulate what sanitizePreview returns
    const mockSanitized = {
        id: "test_id_123",
        title: "Test Recipe",
        description: "A test recipe",
        calories: "350-400",
        cuisine: "Italian",
        difficulty: "Easy",
        servings: 2,
        ingredients: [{ name: "chicken", quantity: "500", unit: "g" }],
        spices: null,
        spices_common: null,
        spices_optional: null,
        required_extra_ingredients: [],
        steps: [],
        language: "en",
        source: "generated",
        isExpanded: false,
    };

    const response = {
        exact_match_recipes: [mockSanitized],
        extra_ingredient_recipes: [mockSanitized],
    };

    // Simulate what Swift JSONDecoder would do
    const json = JSON.stringify(response);
    console.log("Output JSON length:", json.length);
    console.log("Output (first 500):", json.slice(0, 500));

    // Re-parse to ensure it's valid
    const reparsed = JSON.parse(json);
    console.log("✅ Re-parse OK. Keys:", Object.keys(reparsed));
    console.log("exact_match_recipes count:", reparsed.exact_match_recipes.length);
}

async function main() {
    await testDirectOpenAI();
    await testSanitizeOutput();
}

main().catch(console.error);
