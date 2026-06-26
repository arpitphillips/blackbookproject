-- =============================================================================
-- 007_communication.sql
-- Event-driven communication: per-user channel preferences and the notification
-- ledger. The platform never sends generic newsletters; every message is tied
-- to a category the user controls and carries a measurable-value payload.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Notification preferences  (per user, per category, per channel opt-in)
--   Transactional category is effectively always-on at the app layer, but is
--   represented here uniformly so preferences are fully data-driven.
-- -----------------------------------------------------------------------------
CREATE TABLE notification_preferences (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category   notification_category NOT NULL,
    channel    notification_channel  NOT NULL,
    is_enabled boolean NOT NULL DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, category, channel)
);
CREATE INDEX idx_notif_prefs_user ON notification_preferences(user_id);
CREATE TRIGGER trg_notif_prefs_updated BEFORE UPDATE ON notification_preferences FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Notifications  (the send ledger; also records email engagement for analytics)
--   related_entity_type/id is a soft reference to the triggering record
--   (a lead, a search alert, a promotion, ...) kept generic on purpose.
-- -----------------------------------------------------------------------------
CREATE TABLE notifications (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id          uuid REFERENCES professional_profiles(id) ON DELETE SET NULL,
    category            notification_category NOT NULL,
    channel             notification_channel  NOT NULL DEFAULT 'email',
    status              notification_status   NOT NULL DEFAULT 'queued',
    template_key        text,
    subject             text,
    body_preview        text,
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb,
    related_entity_type text,
    related_entity_id   uuid,
    campaign_id         uuid REFERENCES campaigns(id) ON DELETE SET NULL,
    scheduled_for       timestamptz,
    sent_at             timestamptz,
    delivered_at        timestamptz,
    opened_at           timestamptz,      -- email performance
    clicked_at          timestamptz,      -- email performance
    read_at             timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user      ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_status    ON notifications(status);
CREATE INDEX idx_notifications_category  ON notifications(category);
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_for) WHERE status = 'queued';
