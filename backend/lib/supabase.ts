import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

console.log('[SUPABASE] URL configured:', supabaseUrl ? supabaseUrl.substring(0, 40) + '...' : 'EMPTY');
console.log('[SUPABASE] Key configured:', supabaseKey ? `${supabaseKey.substring(0, 10)}... (length: ${supabaseKey.length})` : 'EMPTY');

if (!supabaseUrl || !supabaseKey) {
  console.error('[SUPABASE] WARNING: Missing URL or Key! Cache will NOT work.');
}

export const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    const { count, error } = await supabase
      .from('ai_cache')
      .select('id', { count: 'exact', head: true });
    if (error) {
      console.error('[SUPABASE] Connection test FAILED:', error.message, '| code:', error.code);
    } else {
      console.log('[SUPABASE] Connection test OK. ai_cache rows:', count);
    }
  } catch (e) {
    console.error('[SUPABASE] Connection test exception:', e);
  }
})();
