import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

/** True only when both public env values are present. */
export const supabaseConfigured = Boolean(url && anonKey);

/**
 * Browser client using the public anon key. Writes are constrained by the
 * row-level-security policies in db/supabase/rls.sql (anon may INSERT
 * onboarding submissions and READ active taxonomy — nothing else).
 * Null when env is not configured, so the UI can show setup guidance instead
 * of crashing.
 */
export const supabase: SupabaseClient | null = supabaseConfigured
  ? createClient(url!, anonKey!)
  : null;
