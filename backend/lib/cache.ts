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
  required_ingredients: string[];
  optional_ingredients: string[];
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
    const pgArray = `{${normalized.join(',')}}`;

    const { data: fullMatches, error: fullErr } = await supabase
      .rpc('match_recipes_full', { input_ingredients: pgArray })
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
        .rpc('match_recipes_overlap', { input_ingredients: pgArray })
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
