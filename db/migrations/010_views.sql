-- =============================================================================
-- 010_views.sql
-- Read-model views that back the discovery API and keep query logic DRY.
--   * directory_profiles  - the canonical "live listing" row for search results,
--     with primary category/profession/location denormalized for display.
--   * profile_completeness - derives a completeness percentage from the presence
--     of key profile attributes (the signal the app writes into
--     professional_profiles.completeness_score and that feeds quality scoring).
-- Views add no storage and stay correct as underlying tables change.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- directory_profiles : approved, publicly listable profiles + display joins
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW directory_profiles AS
SELECT
    p.id,
    p.slug,
    p.display_name,
    p.studio_name,
    p.entity_type,
    p.headline,
    p.years_experience,
    p.verification_status,
    p.is_featured,
    p.featured_until,
    p.quality_score,
    p.completeness_score,
    p.view_count,
    p.lead_count,
    p.rate_min,
    p.rate_max,
    p.rate_currency,
    p.rate_display,
    p.travel_willing,
    p.travels_worldwide,
    p.location_id,
    loc.slug          AS location_slug,
    loc.name          AS location_name,
    loc.country_code,
    pcat.category_id  AS primary_category_id,
    cat.slug          AS primary_category_slug,
    cat.name          AS primary_category_name,
    pprof.profession_id AS primary_profession_id,
    prof.slug         AS primary_profession_slug,
    prof.name         AS primary_profession_name,
    av.status         AS availability_status,
    p.published_at,
    p.created_at
FROM professional_profiles p
LEFT JOIN locations          loc   ON loc.id   = p.location_id
LEFT JOIN profile_categories pcat  ON pcat.profile_id  = p.id AND pcat.is_primary
LEFT JOIN categories         cat   ON cat.id   = pcat.category_id
LEFT JOIN profile_professions pprof ON pprof.profile_id = p.id AND pprof.is_primary
LEFT JOIN professions        prof  ON prof.id  = pprof.profession_id
LEFT JOIN availability       av    ON av.profile_id    = p.id
WHERE p.status = 'approved';

-- -----------------------------------------------------------------------------
-- profile_completeness : 0-100 completeness derived from filled attributes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW profile_completeness AS
SELECT
    p.id AS profile_id,
    c.filled,
    c.total,
    round(c.filled * 100.0 / c.total, 1) AS completeness_percent
FROM professional_profiles p
CROSS JOIN LATERAL (
    SELECT
        (
            (p.bio IS NOT NULL AND length(p.bio) > 0)::int
          + (p.headline IS NOT NULL)::int
          + (p.location_id IS NOT NULL)::int
          + (p.years_experience IS NOT NULL)::int
          + ((p.public_email IS NOT NULL) OR (p.public_phone IS NOT NULL))::int
          + EXISTS (SELECT 1 FROM profile_categories  x WHERE x.profile_id = p.id)::int
          + EXISTS (SELECT 1 FROM profile_professions x WHERE x.profile_id = p.id)::int
          + EXISTS (SELECT 1 FROM profile_services    x WHERE x.profile_id = p.id)::int
          + EXISTS (SELECT 1 FROM profile_languages   x WHERE x.profile_id = p.id)::int
          + EXISTS (SELECT 1 FROM portfolio_projects  x WHERE x.profile_id = p.id)::int
          + EXISTS (SELECT 1 FROM portfolio_media     x WHERE x.profile_id = p.id)::int
          + (p.verification_status = 'verified')::int
        ) AS filled,
        12 AS total
) c;
