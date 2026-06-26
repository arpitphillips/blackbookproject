-- =============================================================================
-- 006_monetization.sql
-- The monetization engine: subscriptions, promotions, campaigns, billing.
-- -----------------------------------------------------------------------------
-- Kept deliberately independent of profile management. Revenue is generated
-- through visibility & intelligence (promotions, subscriptions), never by
-- restricting basic discovery. Invoices link to what was sold via line items,
-- which avoids circular FKs between purchases/subscriptions and invoices.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Subscription plans  (catalog of premium tiers)
-- -----------------------------------------------------------------------------
CREATE TABLE subscription_plans (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            citext NOT NULL UNIQUE,
    name            text NOT NULL,
    description     text,
    price           numeric(12,2) NOT NULL DEFAULT 0,
    currency        char(3) NOT NULL DEFAULT 'INR',
    interval        billing_interval NOT NULL DEFAULT 'monthly',
    features        jsonb NOT NULL DEFAULT '{}'::jsonb,     -- entitlements map
    is_active       boolean NOT NULL DEFAULT true,
    sort_order      int NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_subscription_plans_updated BEFORE UPDATE ON subscription_plans FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Subscriptions  (a user's active plan; profile_id optional for multi-profile)
-- -----------------------------------------------------------------------------
CREATE TABLE subscriptions (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id           uuid REFERENCES professional_profiles(id) ON DELETE SET NULL,
    plan_id              uuid NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    status               subscription_status NOT NULL DEFAULT 'trialing',
    current_period_start timestamptz,
    current_period_end   timestamptz,
    trial_ends_at        timestamptz,
    cancel_at            timestamptz,
    cancelled_at         timestamptz,
    amount               numeric(12,2),
    currency             char(3) NOT NULL DEFAULT 'INR',
    external_subscription_id text,                          -- payment gateway ref
    meta                 jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_subscriptions_user   ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE TRIGGER trg_subscriptions_updated BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Promotion products  (catalog of purchasable visibility placements)
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_products (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug          citext NOT NULL UNIQUE,
    name          text NOT NULL,
    description   text,
    placement     promotion_placement NOT NULL,
    price         numeric(12,2) NOT NULL DEFAULT 0,
    currency      char(3) NOT NULL DEFAULT 'INR',
    duration_days int,                                       -- null = until cancelled
    requires_scope boolean NOT NULL DEFAULT false,           -- e.g. category/city feature
    is_active     boolean NOT NULL DEFAULT true,
    meta          jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_promotion_products_updated BEFORE UPDATE ON promotion_products FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Campaigns  (admin-run promotional/email/sponsorship campaigns)
-- -----------------------------------------------------------------------------
CREATE TABLE campaigns (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name           text NOT NULL,
    type           text,                                     -- 'email_spotlight','sponsored',...
    description    text,
    target_filters jsonb NOT NULL DEFAULT '{}'::jsonb,       -- audience targeting
    starts_at      timestamptz,
    ends_at        timestamptz,
    budget         numeric(12,2),
    currency       char(3) NOT NULL DEFAULT 'INR',
    status         text NOT NULL DEFAULT 'draft',            -- draft/scheduled/active/ended
    created_by     uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_campaigns_updated BEFORE UPDATE ON campaigns FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Promotion purchases  (a profile buys a placement; scope = where it applies)
--   When active, the search/recommendation layer reads these to boost/feature
--   and projects is_featured/featured_until onto the profile for fast lookups.
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_purchases (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id        uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    product_id        uuid NOT NULL REFERENCES promotion_products(id) ON DELETE RESTRICT,
    campaign_id       uuid REFERENCES campaigns(id) ON DELETE SET NULL,
    status            purchase_status NOT NULL DEFAULT 'pending',
    scope_category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
    scope_location_id uuid REFERENCES locations(id)  ON DELETE SET NULL,
    starts_at         timestamptz,
    ends_at           timestamptz,
    amount            numeric(12,2),
    currency          char(3) NOT NULL DEFAULT 'INR',
    boost_weight      numeric(6,3) NOT NULL DEFAULT 1.0,     -- feeds ranking
    meta              jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_promo_purchases_profile ON promotion_purchases(profile_id);
CREATE INDEX idx_promo_purchases_status  ON promotion_purchases(status);
-- Active placements are queried at search time by scope:
CREATE INDEX idx_promo_purchases_active ON promotion_purchases(status, ends_at)
    WHERE status = 'active';
CREATE TRIGGER trg_promo_purchases_updated BEFORE UPDATE ON promotion_purchases FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Invoices + line items  (billing for subscriptions and promotions)
-- -----------------------------------------------------------------------------
CREATE TABLE invoices (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    number            text UNIQUE,
    status            invoice_status NOT NULL DEFAULT 'draft',
    subtotal          numeric(12,2) NOT NULL DEFAULT 0,
    tax               numeric(12,2) NOT NULL DEFAULT 0,
    total             numeric(12,2) NOT NULL DEFAULT 0,
    currency          char(3) NOT NULL DEFAULT 'INR',
    issued_at         timestamptz,
    due_at            timestamptz,
    paid_at           timestamptz,
    external_invoice_id text,
    meta              jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_invoices_user   ON invoices(user_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE TRIGGER trg_invoices_updated BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE invoice_line_items (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id           uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description          text NOT NULL,
    quantity             numeric(10,2) NOT NULL DEFAULT 1,
    unit_amount          numeric(12,2) NOT NULL DEFAULT 0,
    amount               numeric(12,2) NOT NULL DEFAULT 0,
    subscription_id      uuid REFERENCES subscriptions(id)       ON DELETE SET NULL,
    promotion_purchase_id uuid REFERENCES promotion_purchases(id) ON DELETE SET NULL,
    meta                 jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX idx_invoice_lines_invoice ON invoice_line_items(invoice_id);
