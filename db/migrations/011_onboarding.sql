-- =============================================================================
-- 011_onboarding.sql
-- Public onboarding intake. The alpha web form writes one row here per
-- submission. Intentionally denormalized and FK-free: it must accept input
-- before the taxonomy is fully populated and before a user/profile exists.
-- Taxonomy choices are stored as slugs (text), multi-values and the complete
-- raw payload as JSONB. A back-office process promotes reviewed submissions
-- into users + professional_profiles (the spec's draft -> approve flow).
--
-- Portable DDL only. Supabase row-level-security (anon INSERT) lives in
-- db/supabase/rls.sql so the core schema stays runnable on vanilla PostgreSQL.
-- =============================================================================

CREATE TABLE onboarding_submissions (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- account / contact
    full_name                text   NOT NULL,
    email                    citext NOT NULL,
    phone                    text,

    -- professional identity
    display_name             text,
    studio_name              text,
    entity_type              text,                 -- individual/studio/agency/collective
    primary_category_slug    text,
    primary_profession_slug  text,
    years_experience         int,
    headline                 text,
    bio                      text,

    -- location & reach
    city                     text,
    country_code             text,
    location_slug            text,
    travel_willing           boolean NOT NULL DEFAULT false,

    -- multi-value selections (slugs / codes)
    specializations          jsonb NOT NULL DEFAULT '[]'::jsonb,
    services                 jsonb NOT NULL DEFAULT '[]'::jsonb,
    languages                jsonb NOT NULL DEFAULT '[]'::jsonb,

    -- links & rate
    website_url              text,
    instagram_url            text,
    rate_min                 numeric(12,2),
    rate_max                 numeric(12,2),
    rate_currency            char(3),
    rate_unit                text,

    -- consent + intake bookkeeping
    consent                  boolean NOT NULL DEFAULT false,
    status                   text NOT NULL DEFAULT 'new',  -- new/reviewing/approved/rejected
    source                   text NOT NULL DEFAULT 'web_alpha',
    raw                      jsonb NOT NULL DEFAULT '{}'::jsonb,  -- full payload, safety net

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_onboarding_rate_range
        CHECK (rate_max IS NULL OR rate_min IS NULL OR rate_max >= rate_min)
);

CREATE INDEX idx_onboarding_status     ON onboarding_submissions(status);
CREATE INDEX idx_onboarding_created    ON onboarding_submissions(created_at DESC);
CREATE INDEX idx_onboarding_email      ON onboarding_submissions(email);

CREATE TRIGGER trg_onboarding_updated
    BEFORE UPDATE ON onboarding_submissions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
