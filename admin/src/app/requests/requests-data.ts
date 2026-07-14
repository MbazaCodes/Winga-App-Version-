import { supabase } from '../../lib/supabase';

export async function getRequests() {
  const { data, error } = await supabase.from('requests').select('*').order('created_at', { ascending: false }).limit(10);
  if (error) throw error;
  return data ?? [];
}
