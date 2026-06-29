-- =============================================================================
-- supabase/rls.sql  -  Supabase-only access control. Run AFTER db/build.sql on
-- the Supabase database. NOT part of build.sql / CI because it references the
-- Supabase-managed `anon` / `authenticated` roles, which do not exist on a
-- vanilla PostgreSQL instance.
--
-- Goal for the alpha:
--   * The browser (anon key) may INSERT onboarding submissions and nothing else.
--   * The browser may READ active taxonomy rows to populate form dropdowns.
--   * The browser may NOT read submissions or touch any other table.
-- Server-side code uses the service-role key, which bypasses RLS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Onboarding intake: anon may INSERT data columns only (never `status`, so it
-- always defaults to 'new'), and may not SELECT/UPDATE/DELETE.
-- -----------------------------------------------------------------------------
ALTER TABLE onboarding_submissions ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT INSERT (
    full_name, email, phone,
    display_name, studio_name, entity_type,
    primary_category_slug, primary_profession_slug, years_experience,
    headline, bio,
    city, country_code, location_slug, travel_willing,
    specializations, services, languages,
    website_url, instagram_url, rate_min, rate_max, rate_currency, rate_unit,
    consent, raw
) ON onboarding_submissions TO anon, authenticated;

DROP POLICY IF EXISTS onboarding_anon_insert ON onboarding_submissions;
CREATE POLICY onboarding_anon_insert
    ON onboarding_submissions
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- Public taxonomy: read-only access to active rows for form dropdowns.
-- -----------------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'categories','professions','specializations','industries',
        'services','languages','locations','tags','equipment'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('GRANT SELECT ON %I TO anon, authenticated', t);
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_read_active', t);
        -- Every table listed above carries an is_active boolean.
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR SELECT TO anon, authenticated USING (is_active)',
            t || '_read_active', t
        );
    END LOOP;
END $$;
