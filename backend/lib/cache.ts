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
    console.log('[CACHE] Searching for ingredients:', normalized);

    const { data: fullMatches, error: fullErr } = await supabase
      .from('ai_cache')
      .select('*')
      .containedBy('required_ingredients', normalized)
      .limit(limit);

    if (fullErr) {
      console.error('[CACHE] Full match query error:', fullErr.message);
    } else {
      console.log('[CACHE] Full matches found:', fullMatches?.length || 0);
    }

    if (!fullErr && fullMatches && fullMatches.length >= limit) {
      return fullMatches.slice(0, limit).map(rowToRecipe);
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

      const { data: overlapMatches, error: overlapErr } = await supabase
        .from('ai_cache')
        .select('*')
        .overlaps('required_ingredients', normalized)
        .limit(remaining + 10);

      if (overlapErr) {
        console.error('[CACHE] Overlap query error:', overlapErr.message);
      } else {
        console.log('[CACHE] Overlap matches found:', overlapMatches?.length || 0);
      }

      if (overlapMatches) {
        const scored = overlapMatches
          .filter(row => !usedIds.has(row.recipe_id))
          .map(row => {
            const reqIngredients: string[] = Array.isArray(row.required_ingredients)
              ? row.required_ingredients
              : (typeof row.required_ingredients === 'string'
                ? row.required_ingredients.replace(/[{}]/g, '').split(',').map((s: string) => s.trim())
                : []);
            const overlap = reqIngredients.filter((i: string) => normalized.includes(i.toLowerCase())).length;
            return { row, overlap };
          })
          .sort((a, b) => b.overlap - a.overlap);

        for (const { row } of scored) {
          if (collected.length >= limit) break;
          collected.push(rowToRecipe(row));
          usedIds.add(row.recipe_id);
        }
      }
    }

    console.log('[CACHE] Total cached recipes returned:', collected.length);
    return collected;
  } catch (err) {
    console.error('[CACHE] Error fetching cached recipes:', err);
    return [];
  }
}

function rowToRecipe(row: any): CachedRecipe {
  const data = row.recipe_data || {};
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
  if (recipes.length === 0) {
    console.log('[CACHE-SAVE] No recipes to save, returning');
    return;
  }

  console.log('[CACHE-SAVE] === START SAVING', recipes.length, 'recipes ===');
  console.log('[CACHE-SAVE] User ingredients:', normalized);

  for (const recipe of recipes) {
    try {
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

      const slugTitle = title
        .toLowerCase()
        .replace(/[^a-z0-9ğüşıöçâîû\s]/g, '')
        .replace(/\s+/g, '_')
        .substring(0, 50);
      const uniqueRecipeId = `${slugTitle}_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;

      const { source, ...recipeWithoutSource } = recipe;

      const insertData = {
        recipe_id: uniqueRecipeId,
        title,
        cuisine,
        difficulty,
        servings,
        required_ingredients: allRequired,
        optional_ingredients: extraIngredients.length > 0 ? extraIngredients : null,
        recipe_data: recipeWithoutSource,
      };

      console.log('[CACHE-SAVE] Inserting recipe:', title, '| recipe_id:', uniqueRecipeId, '| required_ingredients:', allRequired);

      const { data, error } = await supabase
        .from('ai_cache')
        .insert(insertData)
        .select();

      if (error) {
        console.error('[CACHE-SAVE] INSERT FAILED for', title);
        console.error('[CACHE-SAVE] Error:', JSON.stringify({ message: error.message, code: error.code, details: error.details, hint: error.hint }));
      } else {
        console.log('[CACHE-SAVE] INSERT SUCCESS:', title, '| db id:', data?.[0]?.id, '| recipe_id:', uniqueRecipeId);
      }
    } catch (err) {
      console.error('[CACHE] Exception saving recipe:', err);
    }
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
