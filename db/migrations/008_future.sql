-- =============================================================================
-- 008_future.sql
-- Forward-looking tables for products on the roadmap (reviews, client projects,
-- messaging, bookings, payments, collaborations). Created now so the schema is
-- relationally complete and these features need no structural redesign later.
-- They are not yet wired into application flows.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Client projects / briefs  (a hiring Client posts a need)
-- -----------------------------------------------------------------------------
CREATE TABLE projects (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title          text NOT NULL,
    brief          text,
    category_id    uuid REFERENCES categories(id) ON DELETE SET NULL,
    location_id    uuid REFERENCES locations(id)  ON DELETE SET NULL,
    budget_min     numeric(12,2),
    budget_max     numeric(12,2),
    currency       char(3) NOT NULL DEFAULT 'INR',
    status         project_status NOT NULL DEFAULT 'draft',
    deadline       date,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_projects_client ON projects(client_user_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Bookings  (a confirmed engagement of a professional)
-- -----------------------------------------------------------------------------
CREATE TABLE bookings (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id     uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    client_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id     uuid REFERENCES projects(id) ON DELETE SET NULL,
    service_id     uuid REFERENCES services(id) ON DELETE SET NULL,
    status         booking_status NOT NULL DEFAULT 'requested',
    starts_at      timestamptz,
    ends_at        timestamptz,
    amount         numeric(12,2),
    currency       char(3) NOT NULL DEFAULT 'INR',
    location_id    uuid REFERENCES locations(id) ON DELETE SET NULL,
    notes          text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_bookings_profile ON bookings(profile_id);
CREATE INDEX idx_bookings_client  ON bookings(client_user_id);
CREATE TRIGGER trg_bookings_updated BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Payments  (money movement against bookings / invoices)
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    booking_id         uuid REFERENCES bookings(id) ON DELETE SET NULL,
    invoice_id         uuid REFERENCES invoices(id) ON DELETE SET NULL,
    amount             numeric(12,2) NOT NULL,
    currency           char(3) NOT NULL DEFAULT 'INR',
    status             payment_status NOT NULL DEFAULT 'pending',
    method             text,
    external_payment_id text,
    processed_at       timestamptz,
    meta               jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_user    ON payments(user_id);
CREATE INDEX idx_payments_booking ON payments(booking_id);

-- -----------------------------------------------------------------------------
-- Reviews  (verified client reviews of a professional)
-- -----------------------------------------------------------------------------
CREATE TABLE reviews (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id     uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    client_user_id uuid REFERENCES users(id)    ON DELETE SET NULL,
    booking_id     uuid REFERENCES bookings(id) ON DELETE SET NULL,
    lead_id        uuid REFERENCES leads(id)    ON DELETE SET NULL,
    rating         smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title          text,
    body           text,
    status         review_status NOT NULL DEFAULT 'pending',
    is_verified    boolean NOT NULL DEFAULT false,
    response       text,
    responded_at   timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_reviews_profile ON reviews(profile_id);
CREATE INDEX idx_reviews_status  ON reviews(status);
CREATE TRIGGER trg_reviews_updated BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Messaging  (threads + messages between users)
-- -----------------------------------------------------------------------------
CREATE TABLE message_threads (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject    text,
    project_id uuid REFERENCES projects(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_message_threads_updated BEFORE UPDATE ON message_threads FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE messages (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id         uuid NOT NULL REFERENCES message_threads(id) ON DELETE CASCADE,
    sender_user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    profile_id        uuid REFERENCES professional_profiles(id) ON DELETE SET NULL,
    body              text NOT NULL,
    attachments       jsonb NOT NULL DEFAULT '[]'::jsonb,
    read_at           timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_thread ON messages(thread_id, created_at);
CREATE INDEX idx_messages_sender ON messages(sender_user_id);

-- -----------------------------------------------------------------------------
-- Collaborations  (professional-to-professional teaming)
-- -----------------------------------------------------------------------------
CREATE TABLE collaborations (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    initiator_profile_id uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    collaborator_profile_id uuid NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    project_id           uuid REFERENCES projects(id) ON DELETE SET NULL,
    role                 text,
    status               collaboration_status NOT NULL DEFAULT 'proposed',
    notes                text,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_collab_distinct CHECK (initiator_profile_id <> collaborator_profile_id)
);
CREATE INDEX idx_collab_initiator    ON collaborations(initiator_profile_id);
CREATE INDEX idx_collab_collaborator ON collaborations(collaborator_profile_id);
CREATE TRIGGER trg_collaborations_updated BEFORE UPDATE ON collaborations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
