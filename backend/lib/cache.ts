import { supabase } from './supabase';
import crypto from 'crypto';

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

interface CacheRow {
  id: string;
  cache_key: string;
  recipe_data: any;
  recipe_type: string;
  ingredients_key: string;
  language: string;
  hit_count: number;
  created_at: string;
  expires_at: string;
}

const CACHE_TTL_DAYS = 7;

export function generateCacheKey(
  ingredients: string[],
  cuisines: string[],
  servings: number,
  language: string
): string {
  const sortedIngredients = ingredients.map(i => i.toLowerCase().trim()).sort();
  const sortedCuisines = cuisines.map(c => c.toLowerCase().trim()).sort();
  const raw = `${sortedIngredients.join('|')}__${sortedCuisines.join('|')}__${servings}__${language}`;
  return crypto.createHash('sha256').update(raw).digest('hex').substring(0, 48);
}

export function generateIngredientsKey(ingredients: string[]): string {
  return ingredients.map(i => i.toLowerCase().trim()).sort().join('|');
}

export async function getCachedRecipes(
  cacheKey: string,
  exactCount: number,
  extraCount: number
): Promise<{ exact: CachedRecipe[]; extra: CachedRecipe[] } | null> {
  try {
    const { data, error } = await supabase
      .from('ai_cache')
      .select('*')
      .eq('cache_key', cacheKey)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1);

    if (error || !data || data.length === 0) return null;

    const row = data[0] as CacheRow;
    const recipes = row.recipe_data;

    if (!recipes?.exact_match_recipes || !recipes?.extra_ingredient_recipes) return null;

    const exactRecipes = recipes.exact_match_recipes as CachedRecipe[];
    const extraRecipes = recipes.extra_ingredient_recipes as CachedRecipe[];

    if (exactRecipes.length < exactCount || extraRecipes.length < extraCount) return null;

    await supabase
      .from('ai_cache')
      .update({ hit_count: (row.hit_count || 0) + 1 })
      .eq('id', row.id);

    return {
      exact: exactRecipes.slice(0, exactCount),
      extra: extraRecipes.slice(0, extraCount),
    };
  } catch {
    return null;
  }
}

export async function getPartialCachedRecipes(
  cacheKey: string,
  ingredientsKey: string,
  language: string,
  neededExact: number,
  neededExtra: number
): Promise<{ exact: CachedRecipe[]; extra: CachedRecipe[] } | null> {
  try {
    const { data: exactMatch } = await supabase
      .from('ai_cache')
      .select('*')
      .eq('cache_key', cacheKey)
      .gt('expires_at', new Date().toISOString())
      .limit(1);

    if (exactMatch && exactMatch.length > 0) {
      const row = exactMatch[0] as CacheRow;
      const recipes = row.recipe_data;
      if (recipes?.exact_match_recipes?.length >= neededExact &&
          recipes?.extra_ingredient_recipes?.length >= neededExtra) {
        await supabase
          .from('ai_cache')
          .update({ hit_count: (row.hit_count || 0) + 1 })
          .eq('id', row.id);
        return {
          exact: recipes.exact_match_recipes.slice(0, neededExact),
          extra: recipes.extra_ingredient_recipes.slice(0, neededExtra),
        };
      }
    }

    const { data: similarMatches } = await supabase
      .from('ai_cache')
      .select('*')
      .eq('ingredients_key', ingredientsKey)
      .eq('language', language)
      .gt('expires_at', new Date().toISOString())
      .order('hit_count', { ascending: false })
      .limit(3);

    if (!similarMatches || similarMatches.length === 0) return null;

    let collectedExact: CachedRecipe[] = [];
    let collectedExtra: CachedRecipe[] = [];
    const usedTitles = new Set<string>();

    for (const row of similarMatches as CacheRow[]) {
      const recipes = row.recipe_data;
      if (!recipes) continue;

      for (const r of (recipes.exact_match_recipes || [])) {
        if (collectedExact.length >= neededExact) break;
        if (!usedTitles.has(r.title)) {
          usedTitles.add(r.title);
          collectedExact.push(r);
        }
      }
      for (const r of (recipes.extra_ingredient_recipes || [])) {
        if (collectedExtra.length >= neededExtra) break;
        if (!usedTitles.has(r.title)) {
          usedTitles.add(r.title);
          collectedExtra.push(r);
        }
      }
    }

    if (collectedExact.length >= neededExact && collectedExtra.length >= neededExtra) {
      return {
        exact: collectedExact.slice(0, neededExact),
        extra: collectedExtra.slice(0, neededExtra),
      };
    }

    return null;
  } catch {
    return null;
  }
}

export async function storeCacheEntry(
  cacheKey: string,
  ingredientsKey: string,
  language: string,
  recipeData: any
): Promise<void> {
  try {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + CACHE_TTL_DAYS);

    await supabase
      .from('ai_cache')
      .upsert({
        cache_key: cacheKey,
        recipe_data: recipeData,
        recipe_type: 'full_response',
        ingredients_key: ingredientsKey,
        language,
        hit_count: 0,
        expires_at: expiresAt.toISOString(),
      }, { onConflict: 'cache_key' });
  } catch {
    // silent fail
  }
}

export async function getPopularRecipes(
  language: string,
  limit: number = 10
): Promise<CachedRecipe[]> {
  try {
    const { data } = await supabase
      .from('ai_cache')
      .select('recipe_data')
      .eq('language', language)
      .gt('expires_at', new Date().toISOString())
      .order('hit_count', { ascending: false })
      .limit(5);

    if (!data || data.length === 0) return [];

    const allRecipes: CachedRecipe[] = [];
    const usedTitles = new Set<string>();

    for (const row of data) {
      const recipes = row.recipe_data;
      if (!recipes) continue;
      for (const r of [...(recipes.exact_match_recipes || []), ...(recipes.extra_ingredient_recipes || [])]) {
        if (!usedTitles.has(r.title) && allRecipes.length < limit) {
          usedTitles.add(r.title);
          allRecipes.push(r);
        }
      }
    }

    return allRecipes;
  } catch {
    return [];
  }
}

export async function cleanExpiredCache(): Promise<number> {
  try {
    const { data } = await supabase
      .from('ai_cache')
      .delete()
      .lt('expires_at', new Date().toISOString())
      .select('id');
    return data?.length || 0;
  } catch {
    return 0;
  }
}
