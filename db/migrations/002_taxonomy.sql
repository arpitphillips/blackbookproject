-- =============================================================================
-- 002_taxonomy.sql
-- Controlled vocabularies and reference data: the structured backbone that
-- makes professionals searchable, filterable, and recommendable.
-- -----------------------------------------------------------------------------
-- Everything a visitor can filter or search by (category, profession,
-- specialization, industry, service, location, language, equipment, software,
-- notable clients, tags, keywords) is a first-class relational entity here so
-- that profiles link to it by ID instead of repeating free text.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Categories  (top-level discipline; supports sub-categories via parent_id)
--   e.g. Photography > Architectural Photography
-- -----------------------------------------------------------------------------
CREATE TABLE categories (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id       uuid REFERENCES categories(id) ON DELETE SET NULL,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    description     text,
    icon            text,
    image_url       text,
    seo_title       text,
    seo_description text,
    sort_order      int    NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    meta            jsonb  NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_active ON categories(is_active);

-- -----------------------------------------------------------------------------
-- Professions  (belongs to a category)  e.g. "Photographer"
-- -----------------------------------------------------------------------------
CREATE TABLE professions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    description     text,
    seo_title       text,
    seo_description text,
    sort_order      int    NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    meta            jsonb  NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_professions_category ON professions(category_id);
CREATE INDEX idx_professions_active ON professions(is_active);

-- -----------------------------------------------------------------------------
-- Specializations  (belongs to a profession)  e.g. "Wedding Photography"
-- -----------------------------------------------------------------------------
CREATE TABLE specializations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profession_id   uuid NOT NULL REFERENCES professions(id) ON DELETE RESTRICT,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    description     text,
    sort_order      int    NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    meta            jsonb  NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_specializations_profession ON specializations(profession_id);

-- -----------------------------------------------------------------------------
-- Industries  (vertical a professional serves)  e.g. "Real Estate", "Fashion"
-- -----------------------------------------------------------------------------
CREATE TABLE industries (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    description     text,
    sort_order      int    NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Services  (canonical, offered-by-profile via profile_services junction)
-- -----------------------------------------------------------------------------
CREATE TABLE services (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     uuid REFERENCES categories(id) ON DELETE SET NULL,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    description     text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_services_category ON services(category_id);

-- -----------------------------------------------------------------------------
-- Locations  (self-referential geo hierarchy: country>state>city>area)
--   Powers SEO location pages, distance ranking, and city sponsorships.
-- -----------------------------------------------------------------------------
CREATE TABLE locations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id       uuid REFERENCES locations(id) ON DELETE SET NULL,
    type            location_type NOT NULL,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    country_code    char(2),               -- ISO 3166-1 alpha-2
    admin1          text,                  -- state / province
    latitude        numeric(9,6),
    longitude       numeric(9,6),
    timezone        text,
    seo_title       text,
    seo_description text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_locations_parent  ON locations(parent_id);
CREATE INDEX idx_locations_type    ON locations(type);
CREATE INDEX idx_locations_country ON locations(country_code);
CREATE INDEX idx_locations_geo     ON locations(latitude, longitude);

-- -----------------------------------------------------------------------------
-- Languages  (ISO 639)
-- -----------------------------------------------------------------------------
CREATE TABLE languages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code            citext NOT NULL UNIQUE,   -- ISO 639-1 / 639-3
    name            text   NOT NULL,
    native_name     text,
    is_active       boolean NOT NULL DEFAULT true
);

-- -----------------------------------------------------------------------------
-- Tags  (lightweight cross-cutting labels: "drone", "black-and-white", ...)
-- -----------------------------------------------------------------------------
CREATE TABLE tags (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    tag_type        text,                  -- optional grouping ('style','mood',...)
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Equipment  (catalog of gear & software, searchable/filterable)
-- -----------------------------------------------------------------------------
CREATE TABLE equipment (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    type            equipment_type NOT NULL DEFAULT 'other',
    brand           text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_equipment_type ON equipment(type);

-- -----------------------------------------------------------------------------
-- Clients  (brand / company catalog used for the "worked with" credential)
--   NOTE: distinct from the future hiring "Client" *user* (users.role).
-- -----------------------------------------------------------------------------
CREATE TABLE clients (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    industry_id     uuid REFERENCES industries(id) ON DELETE SET NULL,
    slug            citext NOT NULL UNIQUE,
    name            text   NOT NULL,
    logo_url        text,
    website         text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_clients_industry ON clients(industry_id);

-- -----------------------------------------------------------------------------
-- Search keywords  (controlled vocabulary / synonyms for query expansion)
--   Maps a raw search term to the most specific taxonomy node it implies, so
--   the search layer can resolve "real estate photographer" -> profession +
--   industry without structural DB changes when semantic search arrives later.
-- -----------------------------------------------------------------------------
CREATE TABLE search_keywords (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword          citext NOT NULL,
    normalized       text   NOT NULL,                  -- lowercased, de-accented
    category_id      uuid REFERENCES categories(id)       ON DELETE CASCADE,
    profession_id    uuid REFERENCES professions(id)      ON DELETE CASCADE,
    specialization_id uuid REFERENCES specializations(id) ON DELETE CASCADE,
    industry_id      uuid REFERENCES industries(id)       ON DELETE CASCADE,
    weight           numeric(6,3) NOT NULL DEFAULT 1.0,  -- synonym strength
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (keyword, category_id, profession_id, specialization_id, industry_id)
);
CREATE INDEX idx_search_keywords_normalized ON search_keywords(normalized);
CREATE INDEX idx_search_keywords_trgm ON search_keywords USING gin (normalized gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- updated_at triggers
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_categories_updated      BEFORE UPDATE ON categories      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_professions_updated     BEFORE UPDATE ON professions     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_specializations_updated BEFORE UPDATE ON specializations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_industries_updated      BEFORE UPDATE ON industries      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_services_updated        BEFORE UPDATE ON services        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_locations_updated       BEFORE UPDATE ON locations       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_clients_updated         BEFORE UPDATE ON clients         FOR EACH ROW EXECUTE FUNCTION set_updated_at();
