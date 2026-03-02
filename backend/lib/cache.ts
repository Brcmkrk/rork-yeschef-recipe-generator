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
    const { data: allCached, error } = await supabase
      .from('ai_cache')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);

    if (error) {
      console.error('[CACHE] Query error:', error.message);
      return [];
    }

    if (!allCached || allCached.length === 0) return [];

    const scored = allCached.map(row => {
      const reqIngredients: string[] = Array.isArray(row.required_ingredients)
        ? row.required_ingredients.map((s: string) => s.toLowerCase().trim())
        : [];

      const matchCount = reqIngredients.filter(i => normalized.includes(i)).length;
      const totalRequired = reqIngredients.length;
      const matchRatio = totalRequired > 0 ? matchCount / totalRequired : 0;

      return { row, matchCount, matchRatio, totalRequired };
    });

    const fullMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchRatio >= 1.0)
      .sort((a, b) => b.matchCount - a.matchCount);

    const partialMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchRatio >= 0.5 && s.matchRatio < 1.0)
      .sort((a, b) => b.matchRatio - a.matchRatio);

    const collected: CachedRecipe[] = [];
    const usedIds = new Set<string>();

    for (const { row } of fullMatches) {
      if (collected.length >= limit) break;
      const recipe = rowToRecipe(row);
      if (!usedIds.has(recipe.id)) {
        collected.push(recipe);
        usedIds.add(recipe.id);
      }
    }

    for (const { row } of partialMatches) {
      if (collected.length >= limit) break;
      const recipe = rowToRecipe(row);
      if (!usedIds.has(recipe.id)) {
        collected.push(recipe);
        usedIds.add(recipe.id);
      }
    }

    console.log('[CACHE] Found', collected.length, 'cached recipes for ingredients:', normalized.join(', '));
    return collected;
  } catch (err) {
    console.error('[CACHE] Error:', err);
    return [];
  }
}

function rowToRecipe(row: any): CachedRecipe {
  const data = typeof row.recipe_data === 'string'
    ? JSON.parse(row.recipe_data)
    : (row.recipe_data || {});

  return {
    id: data.id || row.recipe_id || `cache_${row.id}`,
    title: data.title || row.title || 'Untitled',
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

  for (const recipe of recipes) {
    try {
      const title = recipe.title || 'Untitled';
      const cuisine = recipe.cuisine || 'International';
      const difficulty = recipe.difficulty || 'Medium';
      const servings = recipe.servings || 2;

      const ingredientNames = (recipe.ingredients || [])
        .map((i: any) => (typeof i === 'string' ? i : i.name || '').toLowerCase().trim())
        .filter(Boolean);

      const extraIngredients = (recipe.required_extra_ingredients || [])
        .map((i: string) => (typeof i === 'string' ? i : '').toLowerCase().trim())
        .filter(Boolean);

      const allRequired = [...new Set([...normalized, ...ingredientNames])];

      const slugTitle = title
        .toLowerCase()
        .replace(/[^a-z0-9ğüşıöçâîû\s]/g, '')
        .replace(/\s+/g, '_')
        .substring(0, 50);
      const uniqueRecipeId = `cache_${slugTitle}_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;

      const { source, ...cleanRecipe } = recipe;

      const recipeDataObj = {
        id: uniqueRecipeId,
        title: cleanRecipe.title,
        calories: cleanRecipe.calories || '300-400',
        cuisine: cleanRecipe.cuisine,
        difficulty: cleanRecipe.difficulty,
        description: cleanRecipe.description || '',
        servings: cleanRecipe.servings || 2,
        ingredients: cleanRecipe.ingredients || [],
        spices: cleanRecipe.spices || [],
        required_extra_ingredients: cleanRecipe.required_extra_ingredients || [],
        steps: cleanRecipe.steps || [],
      };

      const insertData = {
        recipe_id: uniqueRecipeId,
        title,
        cuisine,
        difficulty,
        servings,
        prep_minutes: 10,
        cook_minutes: 15,
        required_ingredients: allRequired,
        optional_ingredients: extraIngredients,
        recipe_data: recipeDataObj,
      };

      console.log('[CACHE-SAVE] Inserting:', title, '| id:', uniqueRecipeId);

      const { data, error } = await supabase
        .from('ai_cache')
        .insert(insertData)
        .select();

      if (error) {
        console.error('[CACHE-SAVE] FAILED:', title, '|', error.message, '| code:', error.code, '| details:', error.details);
      } else {
        console.log('[CACHE-SAVE] SUCCESS:', title, '| db row:', data?.[0]?.id);
      }
    } catch (err) {
      console.error('[CACHE-SAVE] Exception:', err);
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
