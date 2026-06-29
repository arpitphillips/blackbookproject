import type { Database } from '../db.js';
import {
  buildProfessionalSearch,
  type ProfessionalSearchParams,
} from '../search/query.js';

export interface SearchResult {
  items: Record<string, unknown>[];
  total: number;
  page: number;
  pageSize: number;
  pageCount: number;
}

/** Run a directory search and return the page plus the full match total. */
export async function searchProfessionals(
  db: Database,
  params: ProfessionalSearchParams,
): Promise<SearchResult> {
  const { text, values } = buildProfessionalSearch(params);
  const { rows } = await db.query(text, values);

  const total = rows.length > 0 ? Number(rows[0]!.total_count) : 0;
  const items = rows.map(({ total_count, ...rest }) => rest);

  return {
    items,
    total,
    page: params.page,
    pageSize: params.pageSize,
    pageCount: Math.ceil(total / params.pageSize),
  };
}

/**
 * Best-effort analytics write: record the search and which profiles were shown
 * at which position. Callers should not let failures here affect the response.
 */
export async function recordSearch(
  db: Database,
  input: {
    query?: string;
    filters: Record<string, unknown>;
    resultCount: number;
    source?: string;
    items: { id: unknown }[];
  },
): Promise<void> {
  const normalized = input.query ? input.query.trim().toLowerCase() : null;
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO search_logs (search_query, normalized_query, filters, result_count, source)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id`,
    [input.query ?? null, normalized, JSON.stringify(input.filters), input.resultCount, input.source ?? 'api'],
  );
  const searchLogId = rows[0]?.id;
  if (!searchLogId || input.items.length === 0) return;

  // Multi-row impression insert: ($1,$2,1),($1,$3,2),...
  const values: unknown[] = [searchLogId];
  const tuples = input.items.map((item, idx) => {
    values.push(item.id);
    return `($1, $${values.length}, ${idx + 1})`;
  });
  await db.query(
    `INSERT INTO search_impressions (search_log_id, profile_id, position) VALUES ${tuples.join(', ')}`,
    values,
  );
}

/** Full public profile for the detail page, or null if not found/unpublished. */
export async function getProfessionalBySlug(
  db: Database,
  slug: string,
): Promise<Record<string, unknown> | null> {
  const profileRes = await db.query(
    `SELECT p.id, p.slug, p.display_name, p.studio_name, p.entity_type, p.headline,
            p.bio, p.years_experience, p.rate_min, p.rate_max, p.rate_currency,
            p.rate_unit, p.rate_display, p.travel_willing, p.travel_radius_km,
            p.travels_worldwide, p.verification_status, p.quality_score,
            p.completeness_score, p.view_count,
            loc.slug AS location_slug, loc.name AS location_name, loc.country_code
       FROM professional_profiles p
       LEFT JOIN locations loc ON loc.id = p.location_id
      WHERE p.slug = $1 AND p.status = 'approved'`,
    [slug],
  );
  const profile = profileRes.rows[0];
  if (!profile) return null;
  const id = profile.id;

  const [
    categories,
    professions,
    specializations,
    industries,
    services,
    languages,
    tags,
    areasServed,
    equipment,
    clients,
    awards,
    links,
    availability,
    projects,
    media,
  ] = await Promise.all([
    db.query(`SELECT c.slug, c.name, pc.is_primary FROM profile_categories pc JOIN categories c ON c.id = pc.category_id WHERE pc.profile_id = $1 ORDER BY pc.is_primary DESC, c.name`, [id]),
    db.query(`SELECT pr.slug, pr.name, pp.is_primary FROM profile_professions pp JOIN professions pr ON pr.id = pp.profession_id WHERE pp.profile_id = $1 ORDER BY pp.is_primary DESC, pr.name`, [id]),
    db.query(`SELECT s.slug, s.name FROM profile_specializations ps JOIN specializations s ON s.id = ps.specialization_id WHERE ps.profile_id = $1 ORDER BY s.name`, [id]),
    db.query(`SELECT i.slug, i.name FROM profile_industries pi JOIN industries i ON i.id = pi.industry_id WHERE pi.profile_id = $1 ORDER BY i.name`, [id]),
    db.query(`SELECT sv.slug, sv.name, psv.price_from, psv.price_to, psv.currency FROM profile_services psv JOIN services sv ON sv.id = psv.service_id WHERE psv.profile_id = $1 ORDER BY sv.name`, [id]),
    db.query(`SELECT lg.code, lg.name, pl.proficiency FROM profile_languages pl JOIN languages lg ON lg.id = pl.language_id WHERE pl.profile_id = $1 ORDER BY lg.name`, [id]),
    db.query(`SELECT t.slug, t.name FROM profile_tags pt JOIN tags t ON t.id = pt.tag_id WHERE pt.profile_id = $1 ORDER BY t.name`, [id]),
    db.query(`SELECT l.slug, l.name FROM profile_areas_served pas JOIN locations l ON l.id = pas.location_id WHERE pas.profile_id = $1 ORDER BY l.name`, [id]),
    db.query(`SELECT e.slug, e.name, e.type, pe.quantity FROM profile_equipment pe JOIN equipment e ON e.id = pe.equipment_id WHERE pe.profile_id = $1 ORDER BY e.name`, [id]),
    db.query(`SELECT cl.slug, cl.name, cl.logo_url, pcl.engagement_year FROM profile_clients pcl JOIN clients cl ON cl.id = pcl.client_id WHERE pcl.profile_id = $1 ORDER BY pcl.is_featured DESC, cl.name`, [id]),
    db.query(`SELECT title, issuer, award_year, url FROM awards WHERE profile_id = $1 ORDER BY award_year DESC NULLS LAST, sort_order`, [id]),
    db.query(`SELECT link_type, url, label FROM profile_links WHERE profile_id = $1 AND is_public ORDER BY sort_order`, [id]),
    db.query(`SELECT status, available_from, available_until, lead_time_days, accepts_remote, accepts_travel, notes FROM availability WHERE profile_id = $1`, [id]),
    db.query(`SELECT id, slug, title, description, project_year, is_featured FROM portfolio_projects WHERE profile_id = $1 ORDER BY is_featured DESC, sort_order, project_year DESC NULLS LAST`, [id]),
    db.query(`SELECT project_id, type, url, thumbnail_url, title, caption, alt_text, is_cover, sort_order FROM portfolio_media WHERE profile_id = $1 ORDER BY sort_order`, [id]),
  ]);

  // Nest media under their projects.
  const mediaByProject = new Map<unknown, Record<string, unknown>[]>();
  for (const m of media.rows) {
    const list = mediaByProject.get(m.project_id) ?? [];
    const { project_id, ...rest } = m;
    list.push(rest);
    mediaByProject.set(project_id, list);
  }
  const portfolio = projects.rows.map((proj) => ({
    ...proj,
    media: mediaByProject.get(proj.id) ?? [],
  }));

  return {
    ...profile,
    categories: categories.rows,
    professions: professions.rows,
    specializations: specializations.rows,
    industries: industries.rows,
    services: services.rows,
    languages: languages.rows,
    tags: tags.rows,
    areasServed: areasServed.rows,
    equipment: equipment.rows,
    clients: clients.rows,
    awards: awards.rows,
    links: links.rows,
    availability: availability.rows[0] ?? null,
    portfolio,
  };
}

/** Increment the denormalized view counter (fire-and-forget from the route). */
export async function incrementProfileView(db: Database, id: unknown): Promise<void> {
  await db.query(`UPDATE professional_profiles SET view_count = view_count + 1 WHERE id = $1`, [id]);
}
