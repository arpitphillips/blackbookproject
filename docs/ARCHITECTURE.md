# Architecture

This document explains how the database schema in [`db/`](../db) realizes the
Creative Professionals Platform specification. The guiding principle of the
spec is **"the database is the product"**: profiles are the interface, search is
the experience, recommendations are the differentiator, and every column exists
to serve search, recommendation, discoverability, trust, SEO, analytics,
monetization, or collaboration.

## Why a relational schema first

The spec mandates a normalized, platform-agnostic data model that can migrate
from Airtable to PostgreSQL "with minimal redesign." The schema here is written
as plain PostgreSQL DDL with **no Airtable-specific assumptions**:

- **Structured, not free-text.** Anything a visitor can search or filter by
  (category, profession, specialization, industry, service, location, language,
  equipment, software, notable clients, tags, keywords) is a relational entity
  that profiles link to **by ID**. This is the single most important decision
  for search quality, recommendations, and SEO.
- **Normalized.** No duplicated text, no giant catch-all tables, no free-text
  where a relationship belongs. Many-to-many relationships use explicit junction
  tables.
- **UUID primary keys** everywhere, so IDs are globally unique and stable across
  the Airtable → PostgreSQL migration (see [MIGRATION.md](./MIGRATION.md)).
- **Evolvable.** Lifecycle states are enums (extendable with `ALTER TYPE`);
  business taxonomy and tunables live in tables (editable by admins with no
  deploy).

## How the schema maps to the five layers

The spec defines five independent-but-connected layers. The schema is grouped
into migration files along the same seams.

### Layer 1 — Public Discovery

> SEO pages, directory, category/location pages, profiles, search, filters,
> featured & sponsored placements.

Backed by the **taxonomy** tables (`categories`, `professions`,
`specializations`, `industries`, `services`, `locations`, `languages`, `tags`,
`equipment`, `clients`) and the **profile** tables (`professional_profiles` and
its junctions). Every taxonomy and profile row carries `slug`, `seo_title`, and
`seo_description` fields so each category, location, and profile is a
crawlable, indexable page. `locations` is a self-referential hierarchy
(country → state → city → area) that powers location pages and distance
ranking. Featured/sponsored placement is read from the monetization layer and
cached onto the profile (`is_featured`, `featured_until`) for fast filtering.

### Layer 2 — Professional Portal

> Login, profile/portfolio/availability management, analytics, lead inbox,
> verification, subscription, promotions, saved searches.

Backed by `users`, `professional_profiles`, `portfolio_projects`,
`portfolio_media`, `availability`, `verification_records`, `leads`,
`saved_searches`, and the monetization tables. `users.onboarding_step` and
`onboarding_completed` support the friction-minimizing 6-step onboarding with
progress indicators; profiles can stay in `draft`/`pending_review` while the
professional completes them in the dashboard.

### Layer 3 — Recommendation Engine

> Search ranking, similar professionals, frequently-hired-together, suggested
> collaborators/teams, opportunity matching.

Treated as a **separate product**. The schema stores the raw signal
(`search_logs`, `search_impressions`, `profile_views`, `leads`,
`recommendation_events`) and the computed output (`recommendation_scores`).
Crucially, **ranking factor weights are data** (`ranking_factor_weights`),
keyed by `context` (e.g. `search`, `similar`, `collaborator`), so the matching
engine can be re-tuned without code changes — directly satisfying the spec's
"configurable without code changes wherever possible." `recommendation_scores`
stores per-factor contributions in `factors jsonb` plus a `model_version`, so
the ranking model can evolve without schema changes, and future semantic-search
vectors can be added alongside without redesign.

### Layer 4 — Communication

> Event-driven, never generic. Transactional, opportunity, recommendation,
> promotional, and search alerts, all under user control.

Backed by `notification_preferences` (per user × category × channel opt-in) and
`notifications` (the send ledger). The ledger records `opened_at`/`clicked_at`
so email performance is measurable — the foundation for email marketing as a
paid promotional product. `category` is constrained to the spec's communication
taxonomy so no message can be sent outside a controllable category.

### Layer 5 — Monetization

> Visibility, intelligence, and premium tools — never restricting basic
> discovery.

Backed by `subscription_plans`, `subscriptions`, `promotion_products`,
`promotion_purchases`, `campaigns`, `invoices`, and `invoice_line_items`. Kept
**independent of profile management**: a profile is fully functional with no
purchases. Promotions carry a `scope` (category/location) and a `boost_weight`
that the recommendation engine reads, so paid placements integrate naturally
with search and ranking while remaining flagged (`is_sponsored` on impressions).

## Cross-cutting design decisions

| Concern | Decision |
| --- | --- |
| Identity | UUID PKs via `gen_random_uuid()`; `external_ref` on `users`/`professional_profiles` for legacy Airtable record IDs. |
| Multi-profile | `users` 1→N `professional_profiles` (a user may run several listings). |
| `clients` collision | `clients` is the **brand catalog** ("worked with"); the future hiring **Client** is a `users` row with `role = 'client'`. |
| Profile quality | Cached `completeness_score`/`quality_score` on the profile + `profile_score_snapshots` history; feeds ranking. |
| Denormalized counters | `view_count`/`lead_count` and `is_featured`/`featured_until` are caches maintained by the analytics/monetization layers; source-of-truth tables (`profile_views`, `promotion_purchases`) remain authoritative. |
| Auditability | `created_at`/`updated_at` everywhere, the latter maintained by the `set_updated_at()` trigger. |
| High-volume events | `search_logs`, `profile_views`, `recommendation_events`, `notifications` are append-mostly and are obvious future partition targets (by `created_at`). |
| Privacy | Visitor analytics store `ip_hash` and `visitor_session_id`, not raw PII. |

## Building & verifying

```bash
createdb blackbook
psql blackbook -v ON_ERROR_STOP=1 -f db/build.sql   # schema (9 ordered migrations)
psql blackbook -v ON_ERROR_STOP=1 -f db/seed.sql    # minimal reference + demo data
```

The schema has been validated against PostgreSQL 16: it builds clean, the seed
is idempotent, and every foreign key has a supporting index. See
[DATA_MODEL.md](./DATA_MODEL.md) for the table-by-table dictionary and
[ERD.md](./ERD.md) for entity-relationship diagrams.

## What this foundation deliberately leaves open

This iteration is the data foundation. It does **not** include application code,
APIs, auth, or a frontend — those consume this schema. The relational model is
intentionally complete (including future-product tables) so those layers can be
built without structural redesign, and so an eventual Airtable → PostgreSQL cut
is a data migration, not a re-architecture.
