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
      console.error('[CACHE] Query error:', error.message, '| code:', error.code, '| hint:', (error as any).hint);
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
      for (const part of ing.split(' ')) {
        if (part.length >= 2) inputWords.push(part);
      }
    }
    const uniqueInputWords = [...new Set(inputWords)];

    const scored = allCached.map(row => {
      let ingredientNames: string[] = [];

      if (row.required_ingredients) {
        const ri = row.required_ingredients;
        if (Array.isArray(ri)) {
          ingredientNames = ri.map((n: string) => n.toLowerCase().trim()).filter(Boolean);
        } else if (typeof ri === 'string') {
          ingredientNames = ri.replace(/[{}]/g, '').split(',').map((n: string) => n.toLowerCase().trim()).filter(Boolean);
        }
      }

      if (row.optional_ingredients) {
        const oi = row.optional_ingredients;
        if (Array.isArray(oi)) {
          ingredientNames.push(...oi.map((n: string) => n.toLowerCase().trim()).filter(Boolean));
        } else if (typeof oi === 'string') {
          const parsed = oi.replace(/[{}]/g, '').split(',').map((n: string) => n.toLowerCase().trim()).filter(Boolean);
          ingredientNames.push(...parsed);
        }
      }

      if (ingredientNames.length === 0) {
        const data = typeof row.recipe_data === 'string'
          ? JSON.parse(row.recipe_data)
          : (row.recipe_data || {});

        ingredientNames = (data.ingredients || [])
          .map((i: any) => (typeof i === 'string' ? i : i.name || '').toLowerCase().trim())
          .filter(Boolean);
      }

      const recipeText = ingredientNames.join(' ') + ' ' +
        ((row.title || '').toLowerCase()) + ' ' +
        (typeof row.recipe_data === 'object' && row.recipe_data
          ? ((row.recipe_data as any).title || '').toLowerCase() + ' ' + ((row.recipe_data as any).description || '').toLowerCase()
          : '');

      let matchCount = 0;
      const matchedWords: string[] = [];
      for (const word of uniqueInputWords) {
        if (ingredientMatches(word, ingredientNames, recipeText)) {
          matchCount++;
          matchedWords.push(word);
        }
      }

      const totalRequired = ingredientNames.length;

      return { row, matchCount, matchedWords, totalRequired, ingredientNames };
    });

    const rawCount = normalized.length;
    const minForGood = Math.max(2, Math.ceil(rawCount * 0.5));
    const minForPartial = Math.max(1, Math.ceil(rawCount * 0.25));

    const goodMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchCount >= minForGood)
      .sort((a, b) => b.matchCount - a.matchCount);

    const partialMatches = scored
      .filter(s => s.totalRequired > 0 && s.matchCount >= minForPartial && s.matchCount < minForGood)
      .sort((a, b) => b.matchCount - a.matchCount);

    console.log('[CACHE] Input:', normalized.join(', '), '| rawCount:', rawCount, '| minForGood:', minForGood, '| minForPartial:', minForPartial);
    console.log('[CACHE] Good matches:', goodMatches.length, '| Partial matches:', partialMatches.length);

    if (goodMatches.length > 0) {
      console.log('[CACHE] Top good match:', (goodMatches[0].row as any).title || goodMatches[0].row.recipe_id,
        '| matched:', goodMatches[0].matchedWords.join(','), '| recipe ingredients:', goodMatches[0].ingredientNames.join(','));
    }

    const collected: CachedRecipe[] = [];
    const usedIds = new Set<string>();

    for (const { row } of goodMatches) {
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

    console.log('[CACHE] Returning', collected.length, 'cached recipes for ingredients:', normalized.join(', '));
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
    const recipeData = {
      ...rest,
      id: recipeId,
    };

    const ingredientNames = (recipeData.ingredients || [])
      .map((i: any) => typeof i === 'string' ? i.toLowerCase().trim() : (i.name || '').toLowerCase().trim())
      .filter(Boolean);

    const extraIngredients = (recipeData.required_extra_ingredients || [])
      .map((i: any) => typeof i === 'string' ? i.toLowerCase().trim() : '')
      .filter(Boolean);

    return {
      recipe_id: recipeId,
      title: recipeData.title || 'Untitled',
      cuisine: recipeData.cuisine || 'International',
      difficulty: recipeData.difficulty || 'Medium',
      servings: recipeData.servings || 2,
      prep_minutes: recipeData.prep_minutes || 10,
      cook_minutes: recipeData.cook_minutes || 20,
      required_ingredients: ingredientNames,
      optional_ingredients: extraIngredients,
      recipe_data: recipeData,
    };
  });

  console.log('[CACHE-SAVE] Inserting', rows.length, 'recipes to', table, ':', rows.map(r => r.title));
  console.log('[CACHE-SAVE] Row structure sample:', JSON.stringify({
    recipe_id: rows[0]?.recipe_id,
    title: rows[0]?.title,
    required_ingredients: rows[0]?.required_ingredients,
    has_recipe_data: !!rows[0]?.recipe_data,
  }));

  const { data, error } = await supabase
    .from(table)
    .insert(rows)
    .select();

  if (error) {
    console.error('[CACHE-SAVE] FAILED:', error.message, '| code:', error.code, '| hint:', (error as any).hint, '| details:', error.details);

    console.log('[CACHE-SAVE] Retrying with minimal columns...');
    const minimalRows = rows.map(r => ({
      recipe_id: r.recipe_id,
      recipe_data: r.recipe_data,
    }));

    const { data: retryData, error: retryError } = await supabase
      .from(table)
      .insert(minimalRows)
      .select();

    if (retryError) {
      console.error('[CACHE-SAVE] RETRY ALSO FAILED:', retryError.message, '| code:', retryError.code);
    } else {
      console.log('[CACHE-SAVE] RETRY SUCCESS: inserted', retryData?.length, 'rows into', table);
    }
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
