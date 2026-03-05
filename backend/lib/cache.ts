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
  const suffixes = ['ları', 'leri', 'ler', 'lar', 'ies', 'ing', 'ed', 'es', 's'];
  let w = word;
  for (const suffix of suffixes) {
    if (w.length > suffix.length + 2 && w.endsWith(suffix)) {
      w = w.slice(0, -suffix.length);
      break;
    }
  }
  return w;
}

function ingredientMatches(userWord: string, recipeNames: string[]): boolean {
  const word = userWord.toLowerCase().trim();
  if (word.length < 2) return false;
  const stemmed = stemWord(word);

  for (const name of recipeNames) {
    if (name === word) return true;
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

function extractIngredientNames(row: any): string[] {
  const names: string[] = [];

  const data = typeof row.recipe_data === 'string'
    ? (() => { try { return JSON.parse(row.recipe_data); } catch { return {}; } })()
    : (row.recipe_data || {});

  if (data.ingredients && Array.isArray(data.ingredients)) {
    for (const ing of data.ingredients) {
      const n = (typeof ing === 'string' ? ing : (ing.name || '')).toLowerCase().trim();
      if (n) names.push(n);
    }
  }

  if (data.required_extra_ingredients && Array.isArray(data.required_extra_ingredients)) {
    for (const extra of data.required_extra_ingredients) {
      const n = (typeof extra === 'string' ? extra : '').toLowerCase().trim();
      if (n) names.push(n);
    }
  }

  if (row.required_ingredients) {
    const ri = row.required_ingredients;
    let parsed: string[] = [];
    if (Array.isArray(ri)) {
      parsed = ri;
    } else if (typeof ri === 'string') {
      parsed = ri.replace(/[{}\[\]"]/g, '').split(',');
    }
    for (const p of parsed) {
      const n = p.toLowerCase().trim();
      if (n && !names.includes(n)) names.push(n);
    }
  }

  if (row.optional_ingredients) {
    const oi = row.optional_ingredients;
    let parsed: string[] = [];
    if (Array.isArray(oi)) {
      parsed = oi;
    } else if (typeof oi === 'string') {
      parsed = oi.replace(/[{}\[\]"]/g, '').split(',');
    }
    for (const p of parsed) {
      const n = p.toLowerCase().trim();
      if (n && !names.includes(n)) names.push(n);
    }
  }

  return names.filter(Boolean);
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
      .limit(500);

    if (error) {
      console.error('[CACHE] Query error:', error.message, '| code:', error.code);
      return [];
    }

    if (!allCached || allCached.length === 0) {
      console.log('[CACHE] No rows found in table:', table);
      return [];
    }

    console.log('[CACHE] Fetched', allCached.length, 'rows from', table);

    const inputWords: string[] = [];
    for (const ing of normalized) {
      inputWords.push(ing);
      for (const part of ing.split(/[\s,]+/)) {
        if (part.length >= 2 && !inputWords.includes(part)) inputWords.push(part);
      }
    }
    const uniqueInputWords = [...new Set(inputWords)];

    const scored = allCached.map(row => {
      const ingredientNames = extractIngredientNames(row);

      let matchCount = 0;
      const matchedWords: string[] = [];
      for (const word of uniqueInputWords) {
        if (ingredientMatches(word, ingredientNames)) {
          matchCount++;
          matchedWords.push(word);
        }
      }

      const matchRatio = uniqueInputWords.length > 0 ? matchCount / uniqueInputWords.length : 0;

      return { row, matchCount, matchedWords, ingredientNames, matchRatio };
    });

    const rawCount = normalized.length;
    // At least 1 ingredient must match. This allows even single-ingredient overlap.
    const minMatch = 1;

    const goodMatches = scored
      .filter(s => s.ingredientNames.length > 0 && s.matchCount >= minMatch)
      .sort((a, b) => {
        if (b.matchCount !== a.matchCount) return b.matchCount - a.matchCount;
        return b.matchRatio - a.matchRatio;
      });

    // Shuffle top candidates (among recipes with same top matchCount) to get variety
    const topCount = goodMatches[0]?.matchCount ?? 0;
    const topTier = goodMatches.filter(s => s.matchCount === topCount);
    const restTier = goodMatches.filter(s => s.matchCount < topCount);
    // Shuffle top tier for variety
    for (let i = topTier.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [topTier[i], topTier[j]] = [topTier[j], topTier[i]];
    }
    const sorted = [...topTier, ...restTier];

    const partialMatches: typeof scored = []; // kept for logging compatibility

    console.log('[CACHE] Input:', normalized.join(', '), '| words:', uniqueInputWords.join(', '), '| rawCount:', rawCount, '| minMatch:', minMatch);
    console.log('[CACHE] Matches:', sorted.length, '(top matchCount:', topCount, ')');

    if (sorted.length > 0) {
      const top = sorted[0];
      const topData = typeof top.row.recipe_data === 'object' ? top.row.recipe_data : {};
      console.log('[CACHE] Top match:', (topData as any).title || top.row.recipe_id,
        '| matched:', top.matchedWords.join(','),
        '| recipe ingredients:', top.ingredientNames.slice(0, 8).join(','));
    }

    const collected: CachedRecipe[] = [];
    const usedIds = new Set<string>();

    for (const { row } of sorted) {
      if (collected.length >= limit) break;
      const recipe = rowToRecipe(row);
      if (!usedIds.has(recipe.id)) {
        collected.push(recipe);
        usedIds.add(recipe.id);
      }
    }

    console.log('[CACHE] Returning', collected.length, 'cached recipes');
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

export async function saveRecipesToCache(recipes: any[], language: string = 'en'): Promise<void> {
  if (recipes.length === 0) return;

  const table = getCacheTable(language);
  const rows = recipes.map((recipe) => {
    const { source, language: lang, ...rest } = recipe;
    const recipeId = `cache_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const recipeData = { ...rest, id: recipeId };

    const ingredientNames = (recipeData.ingredients || [])
      .map((i: any) => typeof i === 'string' ? i.toLowerCase().trim() : (i.name || '').toLowerCase().trim())
      .filter(Boolean);

    return {
      recipe_id: recipeId,
      recipe_data: recipeData,
      required_ingredients: ingredientNames,
    };
  });

  console.log('[CACHE-SAVE] Inserting', rows.length, 'to', table, ':', rows.map(r => (r.recipe_data as any).title));
  console.log('[CACHE-SAVE] Sample required_ingredients:', rows[0]?.required_ingredients);

  const { data, error } = await supabase
    .from(table)
    .insert(rows)
    .select();

  if (error) {
    console.error('[CACHE-SAVE] Insert failed:', error.message, '| code:', error.code);

    const minimalRows = rows.map(r => ({
      recipe_id: r.recipe_id,
      recipe_data: r.recipe_data,
    }));

    console.log('[CACHE-SAVE] Retrying without required_ingredients column...');
    const { data: retryData, error: retryError } = await supabase
      .from(table)
      .insert(minimalRows)
      .select();

    if (retryError) {
      console.error('[CACHE-SAVE] Retry failed:', retryError.message);
    } else {
      console.log('[CACHE-SAVE] Retry OK:', retryData?.length, 'rows into', table);
    }
  } else {
    console.log('[CACHE-SAVE] OK:', data?.length, 'rows into', table);
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
