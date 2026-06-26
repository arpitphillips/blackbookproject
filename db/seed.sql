-- =============================================================================
-- seed.sql  -  Minimal reference data to exercise the schema end to end.
-- Idempotent: safe to re-run (uses ON CONFLICT on natural slug/code keys).
-- Usage:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/seed.sql
-- =============================================================================
\set ON_ERROR_STOP on

-- ---- Taxonomy --------------------------------------------------------------
INSERT INTO categories (slug, name, description) VALUES
    ('photography', 'Photography', 'Still image capture across disciplines'),
    ('videography', 'Videography', 'Moving image and film production')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO professions (category_id, slug, name)
SELECT id, 'photographer', 'Photographer' FROM categories WHERE slug = 'photography'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO specializations (profession_id, slug, name)
SELECT id, 'architectural-photography', 'Architectural Photography'
FROM professions WHERE slug = 'photographer'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO industries (slug, name) VALUES
    ('real-estate', 'Real Estate'),
    ('fashion', 'Fashion')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO services (slug, name) VALUES
    ('product-shoot', 'Product Shoot'),
    ('wedding-shoot', 'Wedding Shoot')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO locations (type, slug, name, country_code) VALUES
    ('country', 'india', 'India', 'IN')
ON CONFLICT (slug) DO NOTHING;
INSERT INTO locations (type, slug, name, country_code, parent_id)
SELECT 'city', 'mumbai', 'Mumbai', 'IN', id FROM locations WHERE slug = 'india'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO languages (code, name, native_name) VALUES
    ('en', 'English', 'English'),
    ('hi', 'Hindi', 'हिन्दी')
ON CONFLICT (code) DO NOTHING;

INSERT INTO equipment (slug, name, type, brand) VALUES
    ('canon-r5', 'Canon EOS R5', 'camera', 'Canon'),
    ('adobe-lightroom', 'Adobe Lightroom', 'software', 'Adobe')
ON CONFLICT (slug) DO NOTHING;

-- ---- Recommendation weights (configurable, no-code tuning) ------------------
INSERT INTO ranking_factor_weights (factor_key, context, weight, description) VALUES
    ('category_match',     'search', 5.0,  'Profile category matches the query category'),
    ('profession_match',   'search', 4.0,  'Profile profession matches the query'),
    ('distance',           'search', 3.0,  'Inverse distance from searched location'),
    ('verification',       'search', 2.0,  'Verified profiles rank higher'),
    ('completeness',       'search', 1.5,  'Profile completeness score'),
    ('availability',       'search', 1.0,  'Currently available profiles'),
    ('promotion_boost',    'search', 2.5,  'Active promotion weighting')
ON CONFLICT (factor_key, context) DO NOTHING;

-- ---- Monetization catalog --------------------------------------------------
INSERT INTO subscription_plans (slug, name, price, interval, features) VALUES
    ('free',    'Free',    0,    'monthly', '{"portfolio_items": 10}'),
    ('premium', 'Premium', 999,  'monthly', '{"portfolio_items": 100, "analytics": true}')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO promotion_products (slug, name, placement, price, duration_days, requires_scope) VALUES
    ('featured-profile-30d', 'Featured Profile (30 days)', 'featured_profile', 1500, 30, false),
    ('city-feature-mumbai',  'City Feature',               'city_feature',     2500, 30, true)
ON CONFLICT (slug) DO NOTHING;

-- ---- A sample professional, end to end ------------------------------------
INSERT INTO users (email, full_name, role, status, onboarding_completed)
VALUES ('demo.pro@example.com', 'Demo Professional', 'professional', 'active', true)
ON CONFLICT (email) DO NOTHING;

INSERT INTO professional_profiles (user_id, slug, display_name, entity_type, headline, status, location_id, years_experience)
SELECT u.id, 'demo-professional', 'Demo Professional', 'individual',
       'Architectural & product photographer in Mumbai', 'approved',
       l.id, 8
FROM users u, locations l
WHERE u.email = 'demo.pro@example.com' AND l.slug = 'mumbai'
ON CONFLICT (slug) DO NOTHING;

-- Link the sample profile to taxonomy.
INSERT INTO profile_categories (profile_id, category_id, is_primary)
SELECT p.id, c.id, true
FROM professional_profiles p, categories c
WHERE p.slug = 'demo-professional' AND c.slug = 'photography'
ON CONFLICT DO NOTHING;

INSERT INTO profile_professions (profile_id, profession_id, is_primary)
SELECT p.id, pr.id, true
FROM professional_profiles p, professions pr
WHERE p.slug = 'demo-professional' AND pr.slug = 'photographer'
ON CONFLICT DO NOTHING;

INSERT INTO profile_languages (profile_id, language_id, proficiency)
SELECT p.id, lg.id, 'native'
FROM professional_profiles p, languages lg
WHERE p.slug = 'demo-professional' AND lg.code = 'en'
ON CONFLICT DO NOTHING;

INSERT INTO availability (profile_id, status, accepts_remote, accepts_travel)
SELECT id, 'available', true, true
FROM professional_profiles WHERE slug = 'demo-professional'
ON CONFLICT (profile_id) DO NOTHING;
