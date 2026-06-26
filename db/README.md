# Database

Normalized, platform-agnostic PostgreSQL schema for the Creative Professionals
Platform. Plain DDL with no Airtable-specific assumptions — see
[../docs/MIGRATION.md](../docs/MIGRATION.md).

## Layout

| File | Contents |
| --- | --- |
| `migrations/001_extensions_enums.sql` | extensions (`pgcrypto`, `citext`, `pg_trgm`), `set_updated_at()` trigger fn, all enum types |
| `migrations/002_taxonomy.sql` | categories, professions, specializations, industries, services, locations, languages, tags, equipment, clients, search_keywords |
| `migrations/003_users_profiles.sql` | users, professional_profiles |
| `migrations/004_profile_relations.sql` | taxonomy junctions, profile_links, awards, portfolio, verification, availability, score snapshots |
| `migrations/005_engagement.sql` | search_logs, search_impressions, profile_views, leads, saved_searches, ranking_factor_weights, recommendation_scores, recommendation_events |
| `migrations/006_monetization.sql` | subscription_plans, subscriptions, promotion_products, campaigns, promotion_purchases, invoices, invoice_line_items |
| `migrations/007_communication.sql` | notification_preferences, notifications |
| `migrations/008_future.sql` | projects, bookings, payments, reviews, message_threads, messages, collaborations |
| `migrations/009_supporting_indexes.sql` | FK supporting indexes |
| `build.sql` | runs all migrations in order |
| `seed.sql` | minimal idempotent reference + demo data |

Migrations are ordered and additive; run them in numeric order. `build.sql`
does exactly that.

## Build

```bash
createdb blackbook
psql blackbook -v ON_ERROR_STOP=1 -f db/build.sql
psql blackbook -v ON_ERROR_STOP=1 -f db/seed.sql   # optional
```

Run from the repository root so the relative `\i` paths in `build.sql` resolve.

## Conventions

- **Primary keys**: `uuid` via `gen_random_uuid()`.
- **Natural keys**: `slug` (citext) on taxonomy and profiles; `code` on
  languages. Used for SEO URLs and idempotent seeding/migration.
- **Timestamps**: `created_at` on every table; `updated_at` on mutable tables,
  maintained by the `set_updated_at()` `BEFORE UPDATE` trigger.
- **Money**: `numeric(12,2)` + a `char(3)` currency column (default `INR`).
- **Enums** for fixed lifecycle states; **tables** for admin-managed taxonomy
  and tunables. Extend an enum with `ALTER TYPE <name> ADD VALUE '<x>'`.
- **JSONB** (`meta`, `filters`, `factors`, `features`, `payload`) for open-ended
  attributes that should not yet be normalized into columns.
- **Indexes**: every foreign key has a supporting index; partial indexes cover
  hot paths (live profiles, active promotions, queued notifications); trigram
  indexes back fuzzy name/keyword search.

## Adding a migration

Create `migrations/0NN_description.sql`, keep it additive and idempotent where
practical, then append an `\i` line to `build.sql`. Update
[../docs/DATA_MODEL.md](../docs/DATA_MODEL.md) and
[../docs/ERD.md](../docs/ERD.md) to match.
