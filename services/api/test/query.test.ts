import { describe, it, expect } from 'vitest';
import { buildProfessionalSearch, type ProfessionalSearchParams } from '../src/search/query.js';

const base: ProfessionalSearchParams = { sort: 'featured', page: 1, pageSize: 20 };

describe('buildProfessionalSearch', () => {
  it('builds a bare query with no WHERE and default ordering', () => {
    const { text, values } = buildProfessionalSearch(base);
    expect(text).not.toContain('WHERE');
    expect(text).toContain('FROM directory_profiles d');
    expect(text).toContain('ORDER BY d.is_featured DESC');
    // Only LIMIT + OFFSET parameters.
    expect(values).toEqual([20, 0]);
  });

  it('computes OFFSET from page and pageSize', () => {
    const { values } = buildProfessionalSearch({ ...base, page: 3, pageSize: 25 });
    expect(values).toEqual([25, 50]);
  });

  it('binds free-text search as a parameter, never inline (injection-safe)', () => {
    const { text, values } = buildProfessionalSearch({ ...base, q: "x'; DROP TABLE users;--" });
    expect(text).toContain('ILIKE $1');
    expect(values[0]).toBe("%x'; DROP TABLE users;--%");
    expect(text).not.toContain('DROP TABLE');
  });

  it('emits EXISTS facets for taxonomy filters with bound slugs', () => {
    const { text, values } = buildProfessionalSearch({
      ...base,
      category: 'photography',
      service: 'product-shoot',
      language: 'en',
    });
    expect(text).toContain('FROM profile_categories pc');
    expect(text).toContain('FROM profile_services psv');
    expect(text).toContain('FROM profile_languages pl');
    expect(values).toContain('photography');
    expect(values).toContain('product-shoot');
    expect(values).toContain('en');
  });

  it('matches location against base location OR areas served with one param', () => {
    const { text, values } = buildProfessionalSearch({ ...base, location: 'mumbai' });
    expect(text).toContain('d.location_slug =');
    expect(text).toContain('profile_areas_served');
    // The same slug param is reused for both sides of the OR.
    expect(values.filter((v) => v === 'mumbai')).toHaveLength(1);
  });

  it('renders boolean and enum facets', () => {
    const { text } = buildProfessionalSearch({ ...base, verified: true, availability: 'available' });
    expect(text).toContain("d.verification_status = 'verified'");
    expect(text).toContain('d.availability_status = $1::availability_status');
  });

  it('maps each sort key to a distinct ORDER BY', () => {
    expect(buildProfessionalSearch({ ...base, sort: 'name' }).text).toContain('ORDER BY d.display_name ASC');
    expect(buildProfessionalSearch({ ...base, sort: 'recent' }).text).toContain('d.published_at DESC');
    expect(buildProfessionalSearch({ ...base, sort: 'experience' }).text).toContain('d.years_experience DESC');
  });
});
