-- =============================================================================
-- 003_users_profiles.sql
-- Identity (users) and the central entity of the platform (professional
-- profiles). One user may own one or more profiles.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Users  (auth & account identity for every role)
--   Auth credentials may be delegated to an external provider; password_hash
--   is therefore nullable. forms_app_submission_id ties an account back to the
--   forms.app onboarding submission; external_ref aids Airtable migration.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email                  citext NOT NULL UNIQUE,
    phone                  text,
    password_hash          text,
    role                   user_role      NOT NULL DEFAULT 'professional',
    status                 account_status NOT NULL DEFAULT 'pending',
    full_name              text,
    email_verified_at      timestamptz,
    phone_verified_at      timestamptz,
    last_login_at          timestamptz,
    onboarding_step        smallint NOT NULL DEFAULT 1,   -- 1..6 per spec
    onboarding_completed   boolean  NOT NULL DEFAULT false,
    forms_app_submission_id text,
    external_ref           text,                          -- legacy Airtable record id
    meta                   jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_role        ON users(role);
CREATE INDEX idx_users_status      ON users(status);
CREATE INDEX idx_users_external_ref ON users(external_ref);
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Professional profiles  (the directory listing / interface to the database)
--   `completeness_score` and `quality_score` are cached, recomputed values
--   that feed recommendation ranking (see 005). `is_featured`/`featured_until`
--   are cached projections of active promotion_purchases (see 006) kept on the
--   profile for fast search-time filtering; promotion_purchases stays the
--   source of truth. `view_count`/`lead_count` are denormalized counters
--   maintained by the analytics layer.
-- -----------------------------------------------------------------------------
CREATE TABLE professional_profiles (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    slug                citext NOT NULL UNIQUE,            -- SEO profile URL
    display_name        text   NOT NULL,
    studio_name         text,
    entity_type         entity_type NOT NULL DEFAULT 'individual',
    headline            text,
    bio                 text,
    location_id         uuid REFERENCES locations(id) ON DELETE SET NULL,

    -- experience & pricing
    years_experience    smallint,
    rate_min            numeric(12,2),
    rate_max            numeric(12,2),
    rate_currency       char(3) DEFAULT 'INR',
    rate_unit           text,                              -- 'hour','day','project'
    rate_display        rate_visibility NOT NULL DEFAULT 'on_request',

    -- reach
    travel_willing      boolean NOT NULL DEFAULT false,
    travel_radius_km    int,
    travels_worldwide   boolean NOT NULL DEFAULT false,

    -- public contact (visibility governed by *_public flags)
    public_email        citext,
    public_phone        text,
    public_whatsapp     text,
    show_email          boolean NOT NULL DEFAULT false,
    show_phone          boolean NOT NULL DEFAULT false,

    -- lifecycle & moderation
    status              profile_status      NOT NULL DEFAULT 'draft',
    verification_status verification_status NOT NULL DEFAULT 'unverified',
    approved_at         timestamptz,
    approved_by         uuid REFERENCES users(id) ON DELETE SET NULL,
    published_at        timestamptz,
    rejection_reason    text,

    -- cached scores & promotion projection
    completeness_score  numeric(5,2) NOT NULL DEFAULT 0,   -- 0..100
    quality_score       numeric(6,3) NOT NULL DEFAULT 0,
    last_scored_at      timestamptz,
    is_featured         boolean NOT NULL DEFAULT false,
    featured_until      timestamptz,

    -- denormalized analytics counters
    view_count          bigint NOT NULL DEFAULT 0,
    lead_count          bigint NOT NULL DEFAULT 0,

    -- SEO & misc
    seo_title           text,
    seo_description     text,
    meta                jsonb NOT NULL DEFAULT '{}'::jsonb,
    external_ref        text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_rate_range CHECK (rate_max IS NULL OR rate_min IS NULL OR rate_max >= rate_min)
);
CREATE INDEX idx_profiles_user         ON professional_profiles(user_id);
CREATE INDEX idx_profiles_location     ON professional_profiles(location_id);
CREATE INDEX idx_profiles_status       ON professional_profiles(status);
CREATE INDEX idx_profiles_verification ON professional_profiles(verification_status);
CREATE INDEX idx_profiles_featured     ON professional_profiles(is_featured, featured_until);
CREATE INDEX idx_profiles_quality      ON professional_profiles(quality_score DESC);
-- Directory listing pages filter on published+approved profiles constantly:
CREATE INDEX idx_profiles_live         ON professional_profiles(status) WHERE status = 'approved';
CREATE INDEX idx_profiles_display_trgm ON professional_profiles USING gin (display_name gin_trgm_ops);
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON professional_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
