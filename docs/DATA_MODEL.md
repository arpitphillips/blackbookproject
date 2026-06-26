# Data Model

Table-by-table reference for the schema in [`db/migrations`](../db/migrations).
55 tables across seven domains. All primary keys are `uuid` (default
`gen_random_uuid()`); all tables have `created_at`, and mutable tables have an
`updated_at` maintained by the `set_updated_at()` trigger. Only the
distinguishing columns are listed below — see the migration files for full
column lists, types, defaults, checks, and indexes.

Legend: **PK** primary key · **FK** foreign key · **U** unique · `→` references.

---

## 1. Taxonomy & reference (`002_taxonomy.sql`)

The structured vocabulary profiles link to by ID. Editable by admins; no
free-text duplication.

### `categories`
Top-level discipline, self-referential for sub-categories.
| Column | Notes |
| --- | --- |
| `parent_id` FK → categories | sub-category support |
| `slug` U, `name` | SEO category page |
| `seo_title`, `seo_description`, `icon`, `image_url` | discovery/SEO |
| `sort_order`, `is_active`, `meta` jsonb | |

### `professions` → `categories`
A profession within a category (e.g. *Photographer*). `slug` U, SEO fields.

### `specializations` → `professions`
A specialization within a profession (e.g. *Architectural Photography*).

### `industries`
Verticals served (Real Estate, Fashion). `slug` U.

### `services`
Canonical services offered, optionally grouped by `category_id`. Linked to
profiles via `profile_services` (which carries per-profile pricing).

### `locations`
Self-referential geo hierarchy (`type`: country/state/region/city/area/
neighborhood). `country_code`, `admin1`, `latitude`, `longitude`, `timezone`,
SEO fields. Powers location pages, distance ranking, city sponsorships.

### `languages`
ISO 639 `code` U, `name`, `native_name`.

### `tags`
Lightweight cross-cutting labels with optional `tag_type`.

### `equipment`
Gear & software catalog; `type` enum (`camera`…`software`,`tool`), `brand`.

### `clients`
Brand/company catalog for the "worked with" credential (→ `industries`).
**Not** the future hiring client — that is a `users` row.

### `search_keywords`
Controlled synonym vocabulary mapping a raw term to the most specific taxonomy
node (`category_id`/`profession_id`/`specialization_id`/`industry_id`) with a
`weight`. Enables query expansion without structural change when semantic search
arrives. Trigram index on `normalized`.

---

## 2. Identity & profiles (`003_users_profiles.sql`)

### `users`
Account identity for every role.
| Column | Notes |
| --- | --- |
| `email` citext U, `phone`, `password_hash` (nullable; external auth allowed) | |
| `role` enum (professional/client/admin/staff) | |
| `status` enum (pending/active/suspended/deactivated) | |
| `onboarding_step`, `onboarding_completed` | 6-step onboarding + progress |
| `forms_app_submission_id` | forms.app onboarding link |
| `external_ref` | legacy Airtable record id |

### `professional_profiles` → `users`, `locations`
The central entity / directory listing. One user → many profiles.
| Column group | Columns |
| --- | --- |
| Identity | `slug` U, `display_name`, `studio_name`, `entity_type`, `headline`, `bio` |
| Experience/pricing | `years_experience`, `rate_min`/`rate_max`/`rate_currency`/`rate_unit`, `rate_display` |
| Reach | `travel_willing`, `travel_radius_km`, `travels_worldwide` |
| Contact | `public_email`/`public_phone`/`public_whatsapp` + `show_*` visibility flags |
| Lifecycle | `status` enum, `verification_status` enum, `approved_at`, `approved_by` FK→users, `published_at`, `rejection_reason` |
| Cached scores | `completeness_score`, `quality_score`, `last_scored_at` |
| Promotion cache | `is_featured`, `featured_until` (projection of active purchases) |
| Counters | `view_count`, `lead_count` (denormalized) |
| SEO | `seo_title`, `seo_description`, `meta` jsonb, `external_ref` |

Check: `rate_max >= rate_min`. Partial index for live (`approved`) listings;
trigram index on `display_name`.

---

## 3. Profile relations (`004_profile_relations.sql`)

### Taxonomy junctions (composite PK `profile_id` + target)
| Table | Links | Extra |
| --- | --- | --- |
| `profile_categories` | → categories | `is_primary` (≤1 primary, partial unique) |
| `profile_professions` | → professions | `is_primary` (≤1 primary) |
| `profile_specializations` | → specializations | |
| `profile_industries` | → industries | |
| `profile_services` | → services | `price_from`/`price_to`/`currency`/`description` |
| `profile_languages` | → languages | `proficiency` enum |
| `profile_tags` | → tags | |
| `profile_areas_served` | → locations | `travel_surcharge` |
| `profile_equipment` | → equipment | `quantity`, `notes` |
| `profile_clients` | → clients | `engagement_year`, `is_featured` |

### `profile_links` → profiles
External/social links: `link_type`, `url`, `label`, `is_public`, `sort_order`.

### `awards` → profiles
`title`, `issuer`, `award_year`, `description`, `url`.

### `portfolio_projects` → profiles
Body of work. Optional `client_id`/`category_id`/`industry_id`, `project_year`,
`cover_media_id` (FK→portfolio_media), `is_featured`, `view_count`.
U(`profile_id`,`slug`). `portfolio_project_tags` is its tag junction.

### `portfolio_media` → projects, profiles
`type` enum (image/video/audio/document/embed/link), `url`, `thumbnail_url`,
`alt_text` (a11y+SEO), dimensions, `duration_seconds`, `file_size_bytes`,
`is_cover`, `sort_order`.

### `verification_records` → profiles
`type` enum, `status` enum, `document_url`/`document_type`, review trail
(`reviewed_at`, `reviewed_by` FK→users, `reviewer_notes`), `expires_at`.

### `availability` → profiles (1:1, `profile_id` U)
`status` enum, `available_from`/`available_until`, `lead_time_days`,
`accepts_remote`, `accepts_travel`, `notes`.

### `profile_score_snapshots` → profiles
History of `completeness_score`/`quality_score` + `components` jsonb breakdown.

---

## 4. Engagement, search & recommendation (`005_engagement.sql`)

### `search_logs`
One row per query: `search_query`, `normalized_query`, `filters` jsonb,
`category_id`/`profession_id`/`location_id`, `result_count`, `user_id`,
`visitor_session_id`, `ip_hash`, `user_agent`, `referrer`, `source`.

### `search_impressions` → search_logs, profiles
Which profile appeared at which `position`, `is_sponsored`, `clicked`. The
profile ↔ search "many search events" relationship; basis for search-position
analytics.

### `profile_views` → profiles
`viewer_user_id`, `visitor_session_id`, `source`, `referrer`, `location_id`,
`ip_hash`.

### `leads` → profiles
Inbound contact: `name`/`email`/`phone`/`message`, `source` enum, `status` enum,
`budget_min`/`budget_max`, `location_id`, `service_id`, `client_user_id`,
`responded_at`, `converted_at`.

### `saved_searches` → users
Persisted query + `filters` jsonb, `alert_frequency`, `last_alerted_at`. Powers
search-alert emails.

### `ranking_factor_weights`
Data-driven recommendation weighting: `factor_key`, `context`, `weight`,
`is_active`. U(`factor_key`,`context`). Re-tune ranking with no deploy.

### `recommendation_scores` → profiles
Materialized relevance per `context`: `score`, `rank`, `factors` jsonb,
`model_version`. U(`profile_id`,`context`).

### `recommendation_events` → profiles
Impression/click/dismiss/convert/save on recommendations, with
`source_profile_id` ("similar to"), `search_log_id`, viewer, `position`.

---

## 5. Monetization (`006_monetization.sql`)

### `subscription_plans`
Premium tier catalog: `slug` U, `price`/`currency`/`interval`, `features` jsonb.

### `subscriptions` → users, profiles (opt.), subscription_plans
`status` enum, billing period fields, `trial_ends_at`, `cancel_at`,
`external_subscription_id`.

### `promotion_products`
Placement catalog: `placement` enum (featured/homepage/category/city/
recommendation_boost/search_boost/email_spotlight/sponsored), `price`,
`duration_days`, `requires_scope`.

### `campaigns` → users (created_by)
Admin promotional/email/sponsorship campaigns: `type`, `target_filters` jsonb,
schedule, `budget`, `status`.

### `promotion_purchases` → profiles, promotion_products, campaigns (opt.)
A profile's purchased placement: `status` enum, `scope_category_id`/
`scope_location_id`, schedule, `amount`, `boost_weight` (feeds ranking).
Partial index on active placements.

### `invoices` → users
`number` U, `status` enum, `subtotal`/`tax`/`total`/`currency`, issue/due/paid
timestamps, `external_invoice_id`.

### `invoice_line_items` → invoices
`description`, `quantity`, `unit_amount`, `amount`, and **optional** links to
`subscription_id` / `promotion_purchase_id` (avoids circular FKs while still
tying revenue to what was sold).

---

## 6. Communication (`007_communication.sql`)

### `notification_preferences` → users
Per `category` × `channel` opt-in. U(`user_id`,`category`,`channel`).

### `notifications` → users, profiles (opt.), campaigns (opt.)
Send ledger: `category` enum, `channel` enum, `status` enum, `template_key`,
`subject`, `body_preview`, `payload` jsonb, soft `related_entity_type`/
`related_entity_id`, scheduling, and `sent_at`/`delivered_at`/`opened_at`/
`clicked_at`/`read_at` for email-performance analytics.

---

## 7. Future products (`008_future.sql`)

Relationally complete now so no structural redesign is needed later.

| Table | Purpose | Key links |
| --- | --- | --- |
| `projects` | Client brief/need | → users (client), categories, locations |
| `bookings` | Confirmed engagement | → profiles, users, projects, services, locations |
| `payments` | Money movement | → users, bookings, invoices |
| `reviews` | Verified client reviews (rating 1–5) | → profiles, users, bookings, leads |
| `message_threads` / `messages` | In-platform messaging | → users, profiles, projects |
| `collaborations` | Pro-to-pro teaming | → profiles ×2 (distinct), projects |

---

## Enumerated types (`001_extensions_enums.sql`)

`user_role`, `account_status`, `profile_status`, `entity_type`,
`rate_visibility`, `verification_status`, `verification_type`,
`availability_status`, `proficiency_level`, `media_type`, `location_type`,
`lead_status`, `lead_source`, `recommendation_event_type`, `equipment_type`,
`promotion_placement`, `purchase_status`, `subscription_status`,
`billing_interval`, `invoice_status`, `notification_category`,
`notification_channel`, `notification_status`, `review_status`,
`project_status`, `booking_status`, `payment_status`, `collaboration_status`.

Enums cover fixed lifecycle states and are extendable via `ALTER TYPE … ADD
VALUE`. Everything an admin manages (taxonomy, plans, products, ranking weights)
is a table, not an enum.
