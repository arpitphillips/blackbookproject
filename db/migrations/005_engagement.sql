-- =============================================================================
-- 005_engagement.sql
-- Search, analytics, leads, saved searches, and the recommendation substrate.
-- -----------------------------------------------------------------------------
-- These high-volume event tables are the raw material the recommendation engine
-- and analytics dashboards consume. They are intentionally append-mostly and
-- are obvious future partition targets (by created_at) once volume grows.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Search logs  (one row per executed search query)
-- -----------------------------------------------------------------------------
CREATE TABLE search_logs (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    search_query       text,
    normalized_query   text,
    filters            jsonb NOT NULL DEFAULT '{}'::jsonb,   -- structured filter snapshot
    category_id        uuid REFERENCES categories(id)  ON DELETE SET NULL,
    profession_id      uuid REFERENCES professions(id) ON DELETE SET NULL,
    location_id        uuid REFERENCES locations(id)   ON DELETE SET NULL,
    result_count       int,
    user_id            uuid REFERENCES users(id) ON DELETE SET NULL,
    visitor_session_id text,                                 -- anonymous visitor key
    ip_hash            text,                                 -- privacy-preserving
    user_agent         text,
    referrer           text,
    source             text,                                 -- 'directory','category_page',...
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_search_logs_created    ON search_logs(created_at DESC);
CREATE INDEX idx_search_logs_normalized ON search_logs(normalized_query);
CREATE INDEX idx_search_logs_category   ON search_logs(category_id);
CREATE INDEX idx_search_logs_location   ON search_logs(location_id);

-- -----------------------------------------------------------------------------
-- Search impressions  (which profiles appeared, at which position, in a search)
--   This is the profile <-> search "many search events" relationship and the
--   basis for "search position" / "search impressions" analytics.
-- -----------------------------------------------------------------------------
CREATE TABLE search_impressions (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    search_log_id uuid NOT NULL REFERENCES search_logs(id) ON DELETE CASCADE,
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    position      int  NOT NULL,
    is_sponsored  boolean NOT NULL DEFAULT false,
    clicked       boolean NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_search_impressions_profile ON search_impressions(profile_id, created_at DESC);
CREATE INDEX idx_search_impressions_search  ON search_impressions(search_log_id);

-- -----------------------------------------------------------------------------
-- Profile views
-- -----------------------------------------------------------------------------
CREATE TABLE profile_views (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id         uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    viewer_user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
    visitor_session_id text,
    source             text,                                 -- 'search','category','direct',...
    referrer           text,
    location_id        uuid REFERENCES locations(id) ON DELETE SET NULL,
    ip_hash            text,
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_profile_views_profile ON profile_views(profile_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- Leads  (a visitor/client contacting a professional)
-- -----------------------------------------------------------------------------
CREATE TABLE leads (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id         uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    name               text,
    email              citext,
    phone              text,
    message            text,
    source             lead_source NOT NULL DEFAULT 'profile',
    status             lead_status NOT NULL DEFAULT 'new',
    budget_min         numeric(12,2),
    budget_max         numeric(12,2),
    currency           char(3) DEFAULT 'INR',
    location_id        uuid REFERENCES locations(id) ON DELETE SET NULL,
    service_id         uuid REFERENCES services(id)  ON DELETE SET NULL,
    client_user_id     uuid REFERENCES users(id)     ON DELETE SET NULL,
    visitor_session_id text,
    responded_at       timestamptz,
    converted_at       timestamptz,
    meta               jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_leads_profile ON leads(profile_id, created_at DESC);
CREATE INDEX idx_leads_status  ON leads(status);
CREATE TRIGGER trg_leads_updated BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Saved searches  (a user persists a query; powers search-alert emails)
-- -----------------------------------------------------------------------------
CREATE TABLE saved_searches (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            text,
    search_query    text,
    filters         jsonb NOT NULL DEFAULT '{}'::jsonb,
    alert_frequency text NOT NULL DEFAULT 'none',           -- 'none','daily','weekly','instant'
    last_alerted_at timestamptz,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_saved_searches_user ON saved_searches(user_id);
CREATE TRIGGER trg_saved_searches_updated BEFORE UPDATE ON saved_searches FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Ranking factor weights  (configurable recommendation weighting, no code)
--   The matching engine reads weights from here so factors can be re-tuned per
--   context (e.g. 'search', 'similar', 'collaborator') without a deploy.
-- -----------------------------------------------------------------------------
CREATE TABLE ranking_factor_weights (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    factor_key  text NOT NULL,                              -- 'distance','verification',...
    context     text NOT NULL DEFAULT 'default',
    weight      numeric(8,4) NOT NULL DEFAULT 1.0,
    description text,
    is_active   boolean NOT NULL DEFAULT true,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (factor_key, context)
);
CREATE TRIGGER trg_ranking_weights_updated BEFORE UPDATE ON ranking_factor_weights FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Recommendation scores  (materialized relevance per profile per context)
-- -----------------------------------------------------------------------------
CREATE TABLE recommendation_scores (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    context       text NOT NULL,                            -- 'search:<hash>','similar:<profile>',...
    score         numeric(10,5) NOT NULL,
    rank          int,
    factors       jsonb NOT NULL DEFAULT '{}'::jsonb,       -- per-factor contribution
    model_version text,
    computed_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, context)
);
CREATE INDEX idx_rec_scores_context ON recommendation_scores(context, rank);

-- -----------------------------------------------------------------------------
-- Recommendation events  (impressions/clicks on recommended results)
-- -----------------------------------------------------------------------------
CREATE TABLE recommendation_events (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id         uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    event_type         recommendation_event_type NOT NULL,
    context            text,
    source_profile_id  uuid REFERENCES professional_profiles(id) ON DELETE SET NULL, -- "similar to"
    search_log_id      uuid REFERENCES search_logs(id) ON DELETE SET NULL,
    viewer_user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
    visitor_session_id text,
    position           int,
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rec_events_profile ON recommendation_events(profile_id, created_at DESC);
CREATE INDEX idx_rec_events_type    ON recommendation_events(event_type);
