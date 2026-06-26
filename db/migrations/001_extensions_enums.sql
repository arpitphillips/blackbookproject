-- =============================================================================
-- 001_extensions_enums.sql
-- Extensions, helper functions, and enumerated lifecycle types.
-- -----------------------------------------------------------------------------
-- Design notes
--   * UUID primary keys (gen_random_uuid) keep IDs globally unique and stable
--     across an Airtable -> PostgreSQL migration. Every table carries an
--     optional `external_ref` only where a legacy mapping is useful.
--   * ENUM types are used for *fixed lifecycle states* (statuses, channels).
--     Business taxonomy that admins manage lives in TABLES, never enums.
--     Enums can be extended later with `ALTER TYPE ... ADD VALUE`.
--   * `set_updated_at()` keeps `updated_at` honest without application code.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;      -- case-insensitive email / slug
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- fuzzy / ILIKE search acceleration

-- -----------------------------------------------------------------------------
-- updated_at maintenance trigger
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Enumerated lifecycle types
-- -----------------------------------------------------------------------------

-- People / accounts
CREATE TYPE user_role          AS ENUM ('professional', 'client', 'admin', 'staff');
CREATE TYPE account_status     AS ENUM ('pending', 'active', 'suspended', 'deactivated');

-- Professional profiles
CREATE TYPE profile_status     AS ENUM ('draft', 'pending_review', 'approved', 'rejected', 'suspended', 'archived');
CREATE TYPE entity_type        AS ENUM ('individual', 'studio', 'agency', 'collective');
CREATE TYPE rate_visibility    AS ENUM ('hidden', 'range', 'exact', 'on_request');

-- Verification
CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'verified', 'rejected', 'expired');
CREATE TYPE verification_type   AS ENUM ('identity', 'business', 'address', 'professional', 'portfolio_ownership', 'background');

-- Availability
CREATE TYPE availability_status AS ENUM ('available', 'limited', 'unavailable', 'booked');

-- Languages
CREATE TYPE proficiency_level   AS ENUM ('basic', 'conversational', 'fluent', 'native');

-- Media
CREATE TYPE media_type          AS ENUM ('image', 'video', 'audio', 'document', 'embed', 'link');

-- Geography
CREATE TYPE location_type       AS ENUM ('country', 'state', 'region', 'city', 'area', 'neighborhood');

-- Leads
CREATE TYPE lead_status         AS ENUM ('new', 'viewed', 'responded', 'converted', 'closed', 'spam');
CREATE TYPE lead_source         AS ENUM ('profile', 'search', 'recommendation', 'featured', 'referral', 'direct', 'campaign');

-- Recommendation / analytics
CREATE TYPE recommendation_event_type AS ENUM ('impression', 'click', 'dismiss', 'convert', 'save');

-- Equipment catalog
CREATE TYPE equipment_type      AS ENUM ('camera', 'lens', 'lighting', 'audio', 'grip', 'drone', 'software', 'tool', 'other');

-- Monetization
CREATE TYPE promotion_placement AS ENUM (
    'featured_profile', 'homepage_feature', 'category_feature', 'city_feature',
    'recommendation_boost', 'search_boost', 'email_spotlight', 'sponsored_placement'
);
CREATE TYPE purchase_status     AS ENUM ('pending', 'active', 'scheduled', 'expired', 'cancelled', 'refunded');
CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'past_due', 'cancelled', 'expired');
CREATE TYPE billing_interval    AS ENUM ('monthly', 'quarterly', 'annual', 'one_time');
CREATE TYPE invoice_status      AS ENUM ('draft', 'open', 'paid', 'void', 'uncollectible', 'refunded');

-- Communication
CREATE TYPE notification_category AS ENUM (
    'transactional', 'opportunity_alert', 'recommendation_alert',
    'promotional', 'search_alert', 'profile_suggestion'
);
CREATE TYPE notification_channel  AS ENUM ('email', 'sms', 'push', 'in_app');
CREATE TYPE notification_status   AS ENUM ('queued', 'sent', 'delivered', 'failed', 'read', 'bounced');

-- Future products
CREATE TYPE review_status        AS ENUM ('pending', 'published', 'flagged', 'removed');
CREATE TYPE project_status       AS ENUM ('draft', 'open', 'in_progress', 'completed', 'cancelled');
CREATE TYPE booking_status       AS ENUM ('requested', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show');
CREATE TYPE payment_status       AS ENUM ('pending', 'authorized', 'paid', 'failed', 'refunded', 'partially_refunded');
CREATE TYPE collaboration_status AS ENUM ('proposed', 'accepted', 'declined', 'active', 'completed', 'cancelled');
