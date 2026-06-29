/**
 * Search query builder: translates validated filter parameters into a single
 * parameterized SQL statement against the `directory_profiles` view, using
 * EXISTS sub-queries against junction tables for the many-to-many facets.
 *
 * Pure and side-effect free so it can be unit-tested without a database. All
 * user input flows in as bound parameters ($1, $2, …) — never string
 * interpolation — so the builder is injection-safe.
 */

export type SortKey = 'featured' | 'quality' | 'experience' | 'recent' | 'name';

export interface ProfessionalSearchParams {
  q?: string;
  category?: string;
  profession?: string;
  specialization?: string;
  industry?: string;
  service?: string;
  location?: string;
  language?: string;
  availability?: string;
  verified?: boolean;
  featured?: boolean;
  minExperience?: number;
  sort: SortKey;
  page: number;
  pageSize: number;
}

export interface SqlQuery {
  text: string;
  values: unknown[];
}

const SORT_SQL: Record<SortKey, string> = {
  // Default: promoted profiles first, then quality, then popularity.
  featured: 'd.is_featured DESC, d.quality_score DESC, d.view_count DESC',
  quality: 'd.quality_score DESC, d.view_count DESC',
  experience: 'd.years_experience DESC NULLS LAST',
  recent: 'd.published_at DESC NULLS LAST, d.created_at DESC',
  name: 'd.display_name ASC',
};

/** Build the paginated search query; `count(*) OVER()` returns the full total. */
export function buildProfessionalSearch(p: ProfessionalSearchParams): SqlQuery {
  const values: unknown[] = [];
  const where: string[] = [];
  const add = (v: unknown): string => {
    values.push(v);
    return `$${values.length}`;
  };

  if (p.q) {
    const ph = add(`%${p.q}%`);
    where.push(
      `(d.display_name ILIKE ${ph} OR d.headline ILIKE ${ph} OR d.studio_name ILIKE ${ph})`,
    );
  }
  if (p.category) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_categories pc JOIN categories c ON c.id = pc.category_id ` +
        `WHERE pc.profile_id = d.id AND c.slug = ${add(p.category)})`,
    );
  }
  if (p.profession) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_professions pp JOIN professions pr ON pr.id = pp.profession_id ` +
        `WHERE pp.profile_id = d.id AND pr.slug = ${add(p.profession)})`,
    );
  }
  if (p.specialization) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_specializations ps JOIN specializations s ON s.id = ps.specialization_id ` +
        `WHERE ps.profile_id = d.id AND s.slug = ${add(p.specialization)})`,
    );
  }
  if (p.industry) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_industries pi JOIN industries i ON i.id = pi.industry_id ` +
        `WHERE pi.profile_id = d.id AND i.slug = ${add(p.industry)})`,
    );
  }
  if (p.service) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_services psv JOIN services sv ON sv.id = psv.service_id ` +
        `WHERE psv.profile_id = d.id AND sv.slug = ${add(p.service)})`,
    );
  }
  if (p.language) {
    where.push(
      `EXISTS (SELECT 1 FROM profile_languages pl JOIN languages lg ON lg.id = pl.language_id ` +
        `WHERE pl.profile_id = d.id AND lg.code = ${add(p.language)})`,
    );
  }
  if (p.location) {
    const ph = add(p.location);
    where.push(
      `(d.location_slug = ${ph} OR EXISTS (SELECT 1 FROM profile_areas_served pas ` +
        `JOIN locations l ON l.id = pas.location_id WHERE pas.profile_id = d.id AND l.slug = ${ph}))`,
    );
  }
  if (p.availability) {
    where.push(`d.availability_status = ${add(p.availability)}::availability_status`);
  }
  if (p.verified) {
    where.push(`d.verification_status = 'verified'`);
  }
  if (p.featured) {
    where.push(`d.is_featured = true`);
  }
  if (p.minExperience !== undefined) {
    where.push(`d.years_experience >= ${add(p.minExperience)}`);
  }

  const whereSql = where.length ? `WHERE ${where.join('\n    AND ')}` : '';
  const limit = add(p.pageSize);
  const offset = add((p.page - 1) * p.pageSize);

  const text = `
    SELECT
      d.id, d.slug, d.display_name, d.studio_name, d.entity_type, d.headline,
      d.years_experience, d.verification_status, d.is_featured,
      d.quality_score, d.view_count,
      d.rate_min, d.rate_max, d.rate_currency, d.rate_display,
      d.location_slug, d.location_name, d.country_code,
      d.primary_category_slug, d.primary_category_name,
      d.primary_profession_slug, d.primary_profession_name,
      d.availability_status,
      count(*) OVER() AS total_count
    FROM directory_profiles d
    ${whereSql}
    ORDER BY ${SORT_SQL[p.sort]}, d.id
    LIMIT ${limit} OFFSET ${offset}`;

  return { text, values };
}
