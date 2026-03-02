import { supabase } from './supabase';

interface CachedRecipe {
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

interface AiCacheRow {
  id: string;
  recipe_id: string;
  title: string;
  cuisine: string | null;
  difficulty: string | null;
  servings: number | null;
  prep_minutes: number | null;
  cook_minutes: number | null;
  required_ingredients: string;
  optional_ingredients: string | null;
  recipe_data: any;
  created_at: string;
}

function normalizeIngredients(ingredients: string[]): string[] {
  return ingredients.map(i => i.toLowerCase().trim()).filter(Boolean);
}

export async function getCachedRecipesByIngredients(
  userIngredients: string[],
  limit: number = 2
): Promise<CachedRecipe[]> {
  const normalized = normalizeIngredients(userIngredients);
  if (normalized.length === 0) return [];

  try {
    const csvInput = normalized.join(',');

    const { data: fullMatches, error: fullErr } = await supabase
      .rpc('match_recipes_full', { input_ingredients: csvInput })
      .limit(limit);

    if (!fullErr && fullMatches && fullMatches.length >= limit) {
      return fullMatches.map(rowToRecipe);
    }

    const collected: CachedRecipe[] = [];
    const usedIds = new Set<string>();

    if (fullMatches) {
      for (const row of fullMatches) {
        collected.push(rowToRecipe(row));
        usedIds.add(row.recipe_id);
      }
    }

    if (collected.length < limit) {
      const remaining = limit - collected.length;
      const { data: overlapMatches } = await supabase
        .rpc('match_recipes_overlap', { input_ingredients: csvInput })
        .limit(remaining + 5);

      if (overlapMatches) {
        for (const row of overlapMatches) {
          if (collected.length >= limit) break;
          if (!usedIds.has(row.recipe_id)) {
            collected.push(rowToRecipe(row));
            usedIds.add(row.recipe_id);
          }
        }
      }
    }

    return collected;
  } catch (err) {
    console.error('[CACHE] Error fetching cached recipes:', err);
    return [];
  }
}

function rowToRecipe(row: any): CachedRecipe {
  const data = row.recipe_data;
  return {
    id: data.id || row.recipe_id,
    title: data.title || row.title,
    calories: data.calories || '300-400',
    cuisine: data.cuisine || row.cuisine || 'International',
    difficulty: data.difficulty || row.difficulty || 'Medium',
    description: data.description || '',
    servings: data.servings || row.servings || 2,
    ingredients: data.ingredients || [],
    spices: data.spices || [],
    required_extra_ingredients: data.required_extra_ingredients || [],
    steps: data.steps || [],
  };
}

export async function saveRecipesToCache(recipes: any[], userIngredients: string[]): Promise<void> {
  const normalized = normalizeIngredients(userIngredients);
  if (recipes.length === 0) return;

  try {
    for (const recipe of recipes) {
      const recipeId = `auto_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      const title = recipe.title || 'Untitled';
      const cuisine = recipe.cuisine || null;
      const difficulty = recipe.difficulty || null;
      const servings = recipe.servings || 2;

      const ingredientNames = (recipe.ingredients || []).map((i: any) =>
        (typeof i === 'string' ? i : i.name || '').toLowerCase().trim()
      ).filter(Boolean);

      const extraIngredients = (recipe.required_extra_ingredients || []).map((i: string) =>
        i.toLowerCase().trim()
      ).filter(Boolean);

      const allRequired = [...new Set([...normalized, ...ingredientNames])];

      const { error } = await supabase.from('ai_cache').insert({
        recipe_id: recipeId,
        title,
        cuisine,
        difficulty,
        servings,
        required_ingredients: allRequired,
        optional_ingredients: extraIngredients.length > 0 ? extraIngredients : null,
        recipe_data: recipe,
      });

      if (error) {
        console.error('[CACHE] Failed to save recipe to cache:', error.message);
      } else {
        console.log(`[CACHE] Saved recipe to cache: ${title}`);
      }
    }
  } catch (err) {
    console.error('[CACHE] Error saving recipes to cache:', err);
  }
}

export async function getPopularRecipes(
  language: string,
  limit: number = 10
): Promise<CachedRecipe[]> {
  try {
    const { data } = await supabase
      .from('ai_cache')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (!data || data.length === 0) return [];
    return data.map(rowToRecipe);
  } catch {
    return [];
  }
}
