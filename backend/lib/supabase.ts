import { createClient } from '@supabase/supabase-js';

const supabaseUrl =
  process.env.SUPABASE_URL ||
  process.env.EXPO_PUBLIC_SUPABASE_URL ||
  '';

const supabaseKey =
  process.env.SUPABASE_ANON_KEY ||
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ||
  '';

if (!supabaseUrl || !supabaseKey) {
  console.error('[SUPABASE] ❌ MISSING credentials — Supabase will NOT work.');
} else {
  console.log('[SUPABASE] ✅ Configured:', supabaseUrl.split('/').pop());
}

export const supabase = createClient(supabaseUrl, supabaseKey);

// ── Types ────────────────────────────────────────────────────────────────────
export interface RecipeReaction {
  id?: number;
  user_id: string;
  recipe_id: string;
  reaction: 'like' | 'dislike' | 'save';
  created_at?: string;
}

export interface TriedRecipe {
  id?: number;
  user_id: string;
  recipe_id: string;
  recipe_data: any;  // full recipe JSON snapshot
  tried_at?: string;
}

// ── Helpers ──────────────────────────────────────────────────────────────────
export async function getRecipeReaction(userId: string, recipeId: string) {
  const { data, error } = await supabase
    .from('recipe_reactions')
    .select('*')
    .eq('user_id', userId)
    .eq('recipe_id', recipeId)
    .maybeSingle();
  if (error) { console.error('[SUPABASE] getRecipeReaction error:', error.message); return null; }
  return data;
}

export async function upsertRecipeReaction(reaction: RecipeReaction) {
  const { data, error } = await supabase
    .from('recipe_reactions')
    .upsert(reaction, { onConflict: 'user_id,recipe_id' })
    .select()
    .maybeSingle();
  if (error) { console.error('[SUPABASE] upsertRecipeReaction error:', error.message); return null; }
  return data;
}

export async function deleteRecipeReaction(userId: string, recipeId: string) {
  const { error } = await supabase
    .from('recipe_reactions')
    .delete()
    .eq('user_id', userId)
    .eq('recipe_id', recipeId);
  if (error) { console.error('[SUPABASE] deleteRecipeReaction error:', error.message); }
}

export async function getTriedRecipes(userId: string) {
  const { data, error } = await supabase
    .from('tried_recipes')
    .select('*')
    .eq('user_id', userId)
    .order('tried_at', { ascending: false });
  if (error) { console.error('[SUPABASE] getTriedRecipes error:', error.message); return []; }
  return data || [];
}

export async function markRecipeAsTried(entry: TriedRecipe) {
  // Check if already tried
  const { data: existing } = await supabase
    .from('tried_recipes')
    .select('id')
    .eq('user_id', entry.user_id)
    .eq('recipe_id', entry.recipe_id)
    .maybeSingle();

  if (existing) return existing; // already marked

  const { data, error } = await supabase
    .from('tried_recipes')
    .insert(entry)
    .select()
    .maybeSingle();
  if (error) { console.error('[SUPABASE] markRecipeAsTried error:', error.message); return null; }
  return data;
}

export async function logSearchedIngredients(deviceId: string, ingredients: string[], language: string = 'en', latencyMs?: number) {
  if (!deviceId || !ingredients || ingredients.length === 0) return null;
  
  const payload: any = {
      device_id: deviceId,
      ingredients: ingredients,
      language: language
  };
  if (typeof latencyMs === 'number') {
      payload.generation_time_ms = latencyMs;
  }

  const { data, error } = await supabase
    .from('searched_ingredients')
    .insert(payload)
    .select()
    .maybeSingle();
    
  if (error) { console.error('[SUPABASE] logSearchedIngredients error:', error.message); return null; }
  return data;
}
