-- =============================================================================
-- 009_supporting_indexes.sql
-- Supporting indexes for foreign keys that are joined, filtered, or aggregated
-- in real query paths (directory search, analytics rollups, billing
-- reconciliation), and to keep ON DELETE cascades/SET NULL cheap.
-- -----------------------------------------------------------------------------
-- Policy: index every foreign key that is not already the leading column of an
-- existing index. PostgreSQL does not auto-index FKs; on a read-heavy directory
-- the write overhead is well worth the join/scan and referential-action wins.
-- =============================================================================

-- Taxonomy keyword resolution (search layer maps terms -> nodes)
CREATE INDEX idx_search_keywords_category      ON search_keywords(category_id);
CREATE INDEX idx_search_keywords_profession    ON search_keywords(profession_id);
CREATE INDEX idx_search_keywords_specialization ON search_keywords(specialization_id);
CREATE INDEX idx_search_keywords_industry      ON search_keywords(industry_id);

-- Profile moderation / portfolio
CREATE INDEX idx_profiles_approved_by          ON professional_profiles(approved_by);
CREATE INDEX idx_portfolio_projects_industry   ON portfolio_projects(industry_id);
CREATE INDEX idx_portfolio_projects_cover      ON portfolio_projects(cover_media_id);
CREATE INDEX idx_portfolio_project_tags_tag    ON portfolio_project_tags(tag_id);
CREATE INDEX idx_verification_reviewed_by      ON verification_records(reviewed_by);

-- Engagement / analytics
CREATE INDEX idx_search_logs_profession        ON search_logs(profession_id);
CREATE INDEX idx_search_logs_user              ON search_logs(user_id);
CREATE INDEX idx_profile_views_viewer          ON profile_views(viewer_user_id);
CREATE INDEX idx_profile_views_location        ON profile_views(location_id);
CREATE INDEX idx_leads_client_user             ON leads(client_user_id);
CREATE INDEX idx_leads_location                ON leads(location_id);
CREATE INDEX idx_leads_service                 ON leads(service_id);
CREATE INDEX idx_rec_events_source_profile     ON recommendation_events(source_profile_id);
CREATE INDEX idx_rec_events_search_log         ON recommendation_events(search_log_id);
CREATE INDEX idx_rec_events_viewer             ON recommendation_events(viewer_user_id);

-- Monetization
CREATE INDEX idx_subscriptions_plan            ON subscriptions(plan_id);
CREATE INDEX idx_subscriptions_profile         ON subscriptions(profile_id);
CREATE INDEX idx_campaigns_created_by          ON campaigns(created_by);
CREATE INDEX idx_promo_purchases_product       ON promotion_purchases(product_id);
CREATE INDEX idx_promo_purchases_campaign      ON promotion_purchases(campaign_id);
CREATE INDEX idx_promo_purchases_scope_cat     ON promotion_purchases(scope_category_id);
CREATE INDEX idx_promo_purchases_scope_loc     ON promotion_purchases(scope_location_id);
CREATE INDEX idx_invoice_lines_subscription    ON invoice_line_items(subscription_id);
CREATE INDEX idx_invoice_lines_promo_purchase  ON invoice_line_items(promotion_purchase_id);

-- Communication
CREATE INDEX idx_notifications_profile          ON notifications(profile_id);
CREATE INDEX idx_notifications_campaign         ON notifications(campaign_id);

-- Future products
CREATE INDEX idx_projects_category              ON projects(category_id);
CREATE INDEX idx_projects_location              ON projects(location_id);
CREATE INDEX idx_bookings_project              ON bookings(project_id);
CREATE INDEX idx_bookings_service             ON bookings(service_id);
CREATE INDEX idx_bookings_location            ON bookings(location_id);
CREATE INDEX idx_payments_invoice             ON payments(invoice_id);
CREATE INDEX idx_reviews_client_user          ON reviews(client_user_id);
CREATE INDEX idx_reviews_booking              ON reviews(booking_id);
CREATE INDEX idx_reviews_lead                 ON reviews(lead_id);
CREATE INDEX idx_message_threads_project      ON message_threads(project_id);
CREATE INDEX idx_messages_profile             ON messages(profile_id);
CREATE INDEX idx_messages_recipient           ON messages(recipient_user_id);
CREATE INDEX idx_collaborations_project       ON collaborations(project_id);
