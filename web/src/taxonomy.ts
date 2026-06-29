import { supabase } from './supabaseClient';
import type { Option, Taxonomy } from './types';

// Fallback options so the alpha form is usable before the taxonomy tables are
// seeded (or if anon read access isn't configured yet). Once the database has
// taxonomy, these are replaced by live data.
const FALLBACK: Taxonomy = {
  categories: [
    { value: 'photography', label: 'Photography' },
    { value: 'videography', label: 'Videography' },
    { value: 'design', label: 'Design' },
    { value: 'illustration', label: 'Illustration' },
    { value: 'writing', label: 'Writing & Content' },
    { value: 'music-audio', label: 'Music & Audio' },
  ],
  professions: [
    { value: 'photographer', label: 'Photographer', categorySlug: 'photography' },
    { value: 'videographer', label: 'Videographer', categorySlug: 'videography' },
    { value: 'graphic-designer', label: 'Graphic Designer', categorySlug: 'design' },
    { value: 'illustrator', label: 'Illustrator', categorySlug: 'illustration' },
    { value: 'copywriter', label: 'Copywriter', categorySlug: 'writing' },
    { value: 'music-producer', label: 'Music Producer', categorySlug: 'music-audio' },
  ],
  services: [
    { value: 'product-shoot', label: 'Product Shoot' },
    { value: 'wedding-shoot', label: 'Wedding Shoot' },
    { value: 'brand-identity', label: 'Brand Identity' },
    { value: 'social-content', label: 'Social Content' },
  ],
  languages: [
    { value: 'en', label: 'English' },
    { value: 'hi', label: 'Hindi' },
  ],
};

/** Load taxonomy from Supabase, gracefully falling back on any failure. */
export async function loadTaxonomy(): Promise<Taxonomy> {
  if (!supabase) return FALLBACK;
  try {
    const [cats, profs, svcs, langs] = await Promise.all([
      supabase.from('categories').select('slug,name').eq('is_active', true).order('sort_order'),
      supabase.from('professions').select('slug,name,category_id,categories(slug)').eq('is_active', true).order('sort_order'),
      supabase.from('services').select('slug,name').eq('is_active', true).order('name'),
      supabase.from('languages').select('code,name').eq('is_active', true).order('name'),
    ]);

    const categories: Option[] = (cats.data ?? []).map((c) => ({ value: c.slug, label: c.name }));
    const professions: Option[] = (profs.data ?? []).map((p) => ({
      value: p.slug,
      label: p.name,
      categorySlug: (p.categories as { slug?: string } | null)?.slug,
    }));
    const services: Option[] = (svcs.data ?? []).map((s) => ({ value: s.slug, label: s.name }));
    const languages: Option[] = (langs.data ?? []).map((l) => ({ value: l.code, label: l.name }));

    return {
      categories: categories.length ? categories : FALLBACK.categories,
      professions: professions.length ? professions : FALLBACK.professions,
      services: services.length ? services : FALLBACK.services,
      languages: languages.length ? languages : FALLBACK.languages,
    };
  } catch {
    return FALLBACK;
  }
}
