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

function getCacheTable(language: string): string {
  return language === 'tr' ? 'ai_cache_turkish' : 'ai_cache';
}

export async function getCachedRecipesByIngredients(
  userIngredients: string[],
  limit: number = 2,
  language: string = 'en'
): Promise<CachedRecipe[]> {
  const normalized = normalizeIngredients(userIngredients);
  if (normalized.length === 0) return [];

  const table = getCacheTable(language);
  try {
    const { data: allCached, error } = await supabase
      .from(table)
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);

    if (error) {
      console.error('[CACHE] Query error:', error.message);
      return [];
    }

    if (!allCached || allCached.length === 0) return [];

    const scored = allCached.map(row => {
      const data = typeof row.recipe_data === 'string'
        ? JSON.parse(row.recipe_data)
        : (row.recipe_data || {});

      const ingredientNames: string[] = (data.ingredients || [])
        .map((i: any) => (typeof i === 'string' ? i : i.name || '').toLowerCase().trim())
        .filter(Boolean);

      const matchCount = ingredientNames.filter(i => normalized.includes(i)).length;
      const totalRequired = ingredientNames.length;
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
    title: data.title || 'Untitled',
    calories: data.calories || '300-400',
    cuisine: data.cuisine || 'International',
    difficulty: data.difficulty || 'Medium',
    description: data.description || '',
    servings: data.servings || 2,
    ingredients: data.ingredients || [],
    spices: data.spices || [],
    required_extra_ingredients: data.required_extra_ingredients || [],
    steps: data.steps || [],
  };
}

export async function saveRecipesToCache(recipes: any[], language: string = 'en'): Promise<void> {
  if (recipes.length === 0) return;

  const table = getCacheTable(language);
  const rows = recipes.map((recipe) => {
    const { source, language: lang, ...rest } = recipe;
    const recipeId = `cache_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const recipeData = {
      ...rest,
      id: recipeId,
    };
    return {
      recipe_id: recipeId,
      recipe_data: recipeData,
    };
  });

  console.log('[CACHE-SAVE] Inserting', rows.length, 'recipes to', table, ':', rows.map(r => (r.recipe_data as any).title));

  const { data, error } = await supabase
    .from(table)
    .insert(rows)
    .select();

  if (error) {
    console.error('[CACHE-SAVE] FAILED:', error.message, '| code:', error.code, '| hint:', (error as any).hint, '| details:', error.details);
  } else {
    console.log('[CACHE-SAVE] SUCCESS: inserted', data?.length, 'rows into', table);
  }
}

export async function getPopularRecipes(
  language: string,
  limit: number = 10
): Promise<CachedRecipe[]> {
  const table = getCacheTable(language);
  try {
    const { data } = await supabase
      .from(table)
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (!data || data.length === 0) return [];
    return data.map(rowToRecipe);
  } catch {
    return [];
  }
}
