-- =============================================================================
-- 004_profile_relations.sql
-- Everything that hangs off a professional profile: taxonomy links (junctions),
-- owned records (awards, portfolio, verification), and availability.
-- -----------------------------------------------------------------------------
-- Junctions carry an `is_primary` flag where a profile has one principal value
-- (category / profession) but may list several. This avoids duplicating a
-- "primary_*_id" column on the profile while still expressing the relationship.
-- =============================================================================

-- ---- Taxonomy link tables --------------------------------------------------

CREATE TABLE profile_categories (
    profile_id   uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    category_id  uuid NOT NULL REFERENCES categories(id)            ON DELETE CASCADE,
    is_primary   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (profile_id, category_id)
);
CREATE INDEX idx_profile_categories_category ON profile_categories(category_id);
-- At most one primary category per profile:
CREATE UNIQUE INDEX uq_profile_primary_category ON profile_categories(profile_id) WHERE is_primary;

CREATE TABLE profile_professions (
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    profession_id uuid NOT NULL REFERENCES professions(id)           ON DELETE CASCADE,
    is_primary    boolean NOT NULL DEFAULT false,
    PRIMARY KEY (profile_id, profession_id)
);
CREATE INDEX idx_profile_professions_profession ON profile_professions(profession_id);
CREATE UNIQUE INDEX uq_profile_primary_profession ON profile_professions(profile_id) WHERE is_primary;

CREATE TABLE profile_specializations (
    profile_id        uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    specialization_id uuid NOT NULL REFERENCES specializations(id)       ON DELETE CASCADE,
    PRIMARY KEY (profile_id, specialization_id)
);
CREATE INDEX idx_profile_specializations_spec ON profile_specializations(specialization_id);

CREATE TABLE profile_industries (
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    industry_id uuid NOT NULL REFERENCES industries(id)            ON DELETE CASCADE,
    PRIMARY KEY (profile_id, industry_id)
);
CREATE INDEX idx_profile_industries_industry ON profile_industries(industry_id);

-- Services junction carries per-profile pricing for that service.
CREATE TABLE profile_services (
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    service_id  uuid NOT NULL REFERENCES services(id)              ON DELETE CASCADE,
    price_from  numeric(12,2),
    price_to    numeric(12,2),
    currency    char(3) DEFAULT 'INR',
    description text,
    PRIMARY KEY (profile_id, service_id)
);
CREATE INDEX idx_profile_services_service ON profile_services(service_id);

CREATE TABLE profile_languages (
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    language_id uuid NOT NULL REFERENCES languages(id)             ON DELETE CASCADE,
    proficiency proficiency_level NOT NULL DEFAULT 'fluent',
    PRIMARY KEY (profile_id, language_id)
);
CREATE INDEX idx_profile_languages_language ON profile_languages(language_id);

CREATE TABLE profile_tags (
    profile_id uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    tag_id     uuid NOT NULL REFERENCES tags(id)                  ON DELETE CASCADE,
    PRIMARY KEY (profile_id, tag_id)
);
CREATE INDEX idx_profile_tags_tag ON profile_tags(tag_id);

-- Areas served = locations a profile covers beyond its base location.
CREATE TABLE profile_areas_served (
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    location_id uuid NOT NULL REFERENCES locations(id)             ON DELETE CASCADE,
    travel_surcharge numeric(12,2),
    PRIMARY KEY (profile_id, location_id)
);
CREATE INDEX idx_profile_areas_location ON profile_areas_served(location_id);

CREATE TABLE profile_equipment (
    profile_id   uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    equipment_id uuid NOT NULL REFERENCES equipment(id)             ON DELETE CASCADE,
    quantity     smallint,
    notes        text,
    PRIMARY KEY (profile_id, equipment_id)
);
CREATE INDEX idx_profile_equipment_equipment ON profile_equipment(equipment_id);

-- "Worked with" credential -> brand catalog.
CREATE TABLE profile_clients (
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    client_id   uuid NOT NULL REFERENCES clients(id)               ON DELETE CASCADE,
    engagement_year smallint,
    is_featured boolean NOT NULL DEFAULT false,
    PRIMARY KEY (profile_id, client_id)
);
CREATE INDEX idx_profile_clients_client ON profile_clients(client_id);

-- External / social links (website, Instagram, Behance, ...).
CREATE TABLE profile_links (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    link_type  text NOT NULL,                  -- 'website','instagram','behance',...
    url        text NOT NULL,
    label      text,
    is_public  boolean NOT NULL DEFAULT true,
    sort_order int NOT NULL DEFAULT 0
);
CREATE INDEX idx_profile_links_profile ON profile_links(profile_id);

-- ---- Owned records ---------------------------------------------------------

CREATE TABLE awards (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id  uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    title       text NOT NULL,
    issuer      text,
    award_year  smallint,
    description text,
    url         text,
    sort_order  int NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_awards_profile ON awards(profile_id);

-- Portfolio projects: a body of work, optionally tied to a client/industry.
CREATE TABLE portfolio_projects (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    slug          citext NOT NULL,
    title         text NOT NULL,
    description   text,
    client_id     uuid REFERENCES clients(id)    ON DELETE SET NULL,
    category_id   uuid REFERENCES categories(id) ON DELETE SET NULL,
    industry_id   uuid REFERENCES industries(id) ON DELETE SET NULL,
    project_year  smallint,
    cover_media_id uuid,                         -- FK added after portfolio_media exists
    is_featured   boolean NOT NULL DEFAULT false,
    sort_order    int NOT NULL DEFAULT 0,
    view_count    bigint NOT NULL DEFAULT 0,
    meta          jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, slug)
);
CREATE INDEX idx_portfolio_projects_profile  ON portfolio_projects(profile_id);
CREATE INDEX idx_portfolio_projects_client   ON portfolio_projects(client_id);
CREATE INDEX idx_portfolio_projects_category ON portfolio_projects(category_id);
CREATE TRIGGER trg_portfolio_projects_updated BEFORE UPDATE ON portfolio_projects FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE portfolio_project_tags (
    project_id uuid NOT NULL REFERENCES portfolio_projects(id) ON DELETE CASCADE,
    tag_id     uuid NOT NULL REFERENCES tags(id)               ON DELETE CASCADE,
    PRIMARY KEY (project_id, tag_id)
);

-- Individual media assets within a project.
CREATE TABLE portfolio_media (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES portfolio_projects(id) ON DELETE CASCADE,
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    type          media_type NOT NULL DEFAULT 'image',
    url           text NOT NULL,
    thumbnail_url text,
    title         text,
    caption       text,
    alt_text      text,                          -- accessibility + SEO
    width         int,
    height        int,
    duration_seconds int,
    file_size_bytes  bigint,
    is_cover      boolean NOT NULL DEFAULT false,
    sort_order    int NOT NULL DEFAULT 0,
    meta          jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_portfolio_media_project ON portfolio_media(project_id);
CREATE INDEX idx_portfolio_media_profile ON portfolio_media(profile_id);

-- Now that portfolio_media exists, wire the project cover image FK.
ALTER TABLE portfolio_projects
    ADD CONSTRAINT fk_portfolio_projects_cover
    FOREIGN KEY (cover_media_id) REFERENCES portfolio_media(id) ON DELETE SET NULL;

-- Verification document submissions & review trail.
CREATE TABLE verification_records (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id    uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    type          verification_type   NOT NULL,
    status        verification_status NOT NULL DEFAULT 'pending',
    document_url  text,
    document_type text,
    submitted_at  timestamptz NOT NULL DEFAULT now(),
    reviewed_at   timestamptz,
    reviewed_by   uuid REFERENCES users(id) ON DELETE SET NULL,
    reviewer_notes text,
    expires_at    timestamptz,
    meta          jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX idx_verification_profile ON verification_records(profile_id);
CREATE INDEX idx_verification_status  ON verification_records(status);

-- Availability is a 1:1 current-state record per profile.
CREATE TABLE availability (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      uuid NOT NULL UNIQUE REFERENCES professional_profiles(id) ON DELETE CASCADE,
    status          availability_status NOT NULL DEFAULT 'available',
    available_from  date,
    available_until date,
    lead_time_days  smallint,
    accepts_remote  boolean NOT NULL DEFAULT true,
    accepts_travel  boolean NOT NULL DEFAULT false,
    notes           text,
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_availability_updated BEFORE UPDATE ON availability FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Point-in-time snapshots of the profile quality score (analytics & tuning).
CREATE TABLE profile_score_snapshots (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id         uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    completeness_score numeric(5,2) NOT NULL,
    quality_score      numeric(6,3) NOT NULL,
    components         jsonb NOT NULL DEFAULT '{}'::jsonb,   -- factor breakdown
    computed_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_score_snapshots_profile ON profile_score_snapshots(profile_id, computed_at DESC);
