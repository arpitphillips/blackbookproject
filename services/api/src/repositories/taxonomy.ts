import type { Database } from '../db.js';

/** Active categories (optionally only a parent's sub-categories) for filter UIs. */
export async function listCategories(db: Database, parentSlug?: string) {
  if (parentSlug) {
    const { rows } = await db.query(
      `SELECT c.slug, c.name, c.description, c.parent_id
         FROM categories c
         JOIN categories parent ON parent.id = c.parent_id
        WHERE c.is_active AND parent.slug = $1
        ORDER BY c.sort_order, c.name`,
      [parentSlug],
    );
    return rows;
  }
  const { rows } = await db.query(
    `SELECT slug, name, description, parent_id
       FROM categories
      WHERE is_active
      ORDER BY sort_order, name`,
  );
  return rows;
}

/** Active professions, optionally scoped to a category slug. */
export async function listProfessions(db: Database, categorySlug?: string) {
  if (categorySlug) {
    const { rows } = await db.query(
      `SELECT pr.slug, pr.name, c.slug AS category_slug
         FROM professions pr
         JOIN categories c ON c.id = pr.category_id
        WHERE pr.is_active AND c.slug = $1
        ORDER BY pr.sort_order, pr.name`,
      [categorySlug],
    );
    return rows;
  }
  const { rows } = await db.query(
    `SELECT pr.slug, pr.name, c.slug AS category_slug
       FROM professions pr
       JOIN categories c ON c.id = pr.category_id
      WHERE pr.is_active
      ORDER BY pr.sort_order, pr.name`,
  );
  return rows;
}

/** Active locations, optionally filtered by type (country/state/city/...). */
export async function listLocations(db: Database, type?: string) {
  if (type) {
    const { rows } = await db.query(
      `SELECT slug, name, type, country_code, parent_id
         FROM locations
        WHERE is_active AND type = $1::location_type
        ORDER BY name`,
      [type],
    );
    return rows;
  }
  const { rows } = await db.query(
    `SELECT slug, name, type, country_code, parent_id
       FROM locations
      WHERE is_active
      ORDER BY type, name`,
  );
  return rows;
}
