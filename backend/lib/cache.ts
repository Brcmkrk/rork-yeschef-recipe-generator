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

function stemWord(word: string): string {
  const suffixes = ['ler', 'lar', 'ları', 'leri', 'es', 's', 'ies', 'ed', 'ing'];
  let w = word;
  for (const suffix of suffixes) {
    if (w.length > suffix.length + 2 && w.endsWith(suffix)) {
      w = w.slice(0, -suffix.length);
      break;
    }
  }
  return w;
}

function ingredientMatches(userWord: string, recipeNames: string[], recipeText: string): boolean {
  const word = userWord.toLowerCase().trim();
  if (word.length < 2) return false;
  const stemmed = stemWord(word);

  if (recipeText.includes(word)) return true;
  if (stemmed.length >= 3 && recipeText.includes(stemmed)) return true;

  for (const name of recipeNames) {
    if (name.includes(word) || word.includes(name)) return true;
    const nameStemmed = stemWord(name);
    if (stemmed.length >= 3 && nameStemmed.length >= 3) {
      if (nameStemmed.includes(stemmed) || stemmed.includes(nameStemmed)) return true;
    }
  }
  return false;
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

    const inputWords: string[] = [];
    for (const ing of normalized) {
      inputWords.push(ing);
      for (const part of ing.split(' ')) {
        if (part.length >= 2) inputWords.push(part);
      }
    }
    const uniqueInputWords = [...new Set(inputWords)];

    const scored = allCached.map(row => {
      const data = typeof row.recipe_data === 'string'
        ? JSON.parse(row.recipe_data)
        : (row.recipe_data || {});

      const ingredientNames: string[] = (data.ingredients || [])
        .map((i: any) => (typeof i === 'string' ? i : i.name || '').toLowerCase().trim())
        .filter(Boolean);

      const recipeText = [...ingredientNames, (data.title || '').toLowerCase(), (data.description || '').toLowerCase()].join(' ');

      let matchCount = 0;
      for (const word of uniqueInputWords) {
        if (ingredientMatches(word, ingredientNames, recipeText)) {
          matchCount++;
        }
      }

      const totalRequired = ingredientNames.length;
      const matchRatio = totalRequired > 0 ? matchCount / Math.max(totalRequired, uniqueInputWords.length) : 0;

      return { row, matchCount, matchRatio, totalRequired };
    });

    const rawCount = normalized.length;
    const threshold = rawCount <= 2 ? 1 : Math.max(1, Math.ceil(rawCount * 0.2));

    const fullMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchCount >= Math.max(2, rawCount))
      .sort((a, b) => b.matchCount - a.matchCount);

    const partialMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchCount >= threshold && s.matchCount < Math.max(2, rawCount))
      .sort((a, b) => b.matchCount - a.matchCount);

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

    console.log('[CACHE] Found', collected.length, 'cached recipes from', allCached.length, 'total rows for ingredients:', normalized.join(', '), '| inputWords:', uniqueInputWords.join(','), '| threshold:', threshold);
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
