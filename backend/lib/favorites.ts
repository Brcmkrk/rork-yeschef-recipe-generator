import { supabase } from '@/lib/supabase';

export type Recipe = {
    id?: string;
    title?: string;
    [key: string]: any;
};

export type Favorite = {
    id: string;
    user_id: string;
    recipe_id: string;
    recipe: Recipe;
    created_at: string;
};

/**
 * Adds a recipe to the favorites table.
 * Assumes a default user_id or requires it to be provided.
 * For this integration, we will require user_id as a parameter if not globally available.
 * Let's assume we pass user_id down or use a dummy 'default_user' if none is given.
 */
export async function addFavorite(recipe: Recipe, user_id: string = 'default_user') {
    if (!recipe.id) {
        throw new Error('Recipe must have an id to be favorited');
    }

    const { data, error } = await supabase
        .from('favorites')
        .insert([
            {
                user_id,
                recipe_id: recipe.id,
                recipe,
            },
        ])
        .select()
        .single();

    if (error) {
        console.error('Error adding favorite:', error);
        throw error;
    }

    return data as Favorite;
}

/**
 * Removes a recipe from the favorites table by recipe_id.
 */
export async function removeFavorite(recipe_id: string, user_id: string = 'default_user') {
    const { error } = await supabase
        .from('favorites')
        .delete()
        .match({ recipe_id, user_id });

    if (error) {
        console.error('Error removing favorite:', error);
        throw error;
    }

    return true;
}

/**
 * Retrieves all favorite recipes for a given user_id.
 */
export async function getFavorites(user_id: string = 'default_user') {
    const { data, error } = await supabase
        .from('favorites')
        .select('*')
        .eq('user_id', user_id)
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching favorites:', error);
        throw error;
    }

    return data as Favorite[];
}
