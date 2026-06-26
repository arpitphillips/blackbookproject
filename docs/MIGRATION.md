# Airtable → PostgreSQL Migration Strategy

The spec requires that the platform "remain platform-agnostic so Airtable can
eventually be replaced with PostgreSQL or another relational database with
minimal redesign," and to "avoid Airtable-specific assumptions." This schema is
designed so that switching the operational database is a **data migration, not a
re-architecture**.

## Why this schema migrates cleanly

| Airtable habit (avoided) | This schema (instead) |
| --- | --- |
| Multi-select / lookup fields holding repeated text | Junction tables (`profile_*`) linking by UUID |
| Free-text for category/location/skill | First-class taxonomy tables linked by ID |
| Record links as the only identity | UUID surrogate PKs + `slug` natural keys |
| Computed/rollup fields baked into rows | Derived values either computed in queries or stored as clearly-labelled caches (`view_count`, `quality_score`, `is_featured`) |
| One wide table per "view" | Normalized tables, one concern each |

Because every entity already has a stable UUID and natural `slug`/`code` keys,
nothing depends on Airtable's internal `recXXXXXXXX` IDs at runtime.

## The `external_ref` bridge

`users` and `professional_profiles` carry an `external_ref` column to hold the
originating Airtable record ID during migration. This lets the importer:

1. Insert/upsert rows while remembering their Airtable origin.
2. Resolve Airtable record-link fields to new UUID foreign keys in a second
   pass (look up the target by `external_ref`, then set the FK).
3. Re-run idempotently (match on `external_ref` / `slug` instead of inserting
   duplicates).

Other tables can adopt the same pattern if needed; `external_ref` is cheap to
add via `ALTER TABLE` and can be dropped once migration is complete.

## Recommended migration sequence

1. **Stand up the schema.** `psql -f db/build.sql` against the target Postgres.
2. **Seed reference data.** Categories, professions, specializations,
   industries, services, locations, languages, equipment, tags — these are the
   join targets and must exist before profiles. Map each Airtable option/record
   to a row, recording `external_ref` and assigning a `slug`.
3. **Import users**, then **profiles** (`external_ref` = Airtable record id).
4. **Resolve links** into junction tables (`profile_categories`,
   `profile_services`, …) by looking up both sides via `external_ref`/`slug`.
5. **Import owned records** (portfolio, awards, verification, availability).
6. **Backfill events** (`search_logs`, `profile_views`, `leads`) if any history
   exists; otherwise start fresh — these are append-mostly.
7. **Recompute caches** (`completeness_score`, `quality_score`,
   `is_featured`/`featured_until`) from source rows; do not trust migrated
   rollups.
8. **Validate**: row counts per table, zero orphaned FKs, no duplicate slugs,
   and spot-check a sample of profiles end to end.

## Mapping Airtable concepts

| Airtable | PostgreSQL here |
| --- | --- |
| Base | Database `blackbook` |
| Table | Table |
| Single line / long text | `text` |
| Single select | enum (fixed lifecycle) **or** FK to a small reference table (admin-managed) |
| Multiple select | junction table to a tag/taxonomy table |
| Linked records | FK (one side) or junction table (many-to-many) |
| Attachment | `*_url` (object-storage URL) + metadata columns in `portfolio_media` |
| Formula / rollup | computed in SQL/views, or a labelled cache column |
| Created/Modified time | `created_at` / `updated_at` (trigger-maintained) |
| Record ID | UUID PK; Airtable id preserved in `external_ref` |

## Forms.app onboarding

`users.forms_app_submission_id` links an account to its forms.app onboarding
submission. During migration, map existing submissions to users via this column;
going forward the onboarding webhook can upsert by it. The 6-step onboarding
maps to `users.onboarding_step` / `onboarding_completed`, with profiles allowed
in `draft`/`pending_review` until completed in the dashboard.

## After the cut-over

- The enums and tables are standard PostgreSQL — no extension beyond `pgcrypto`
  (UUIDs), `citext` (case-insensitive email/slug), and `pg_trgm` (fuzzy search).
- High-volume event tables (`search_logs`, `profile_views`,
  `recommendation_events`, `notifications`) are ready to be converted to
  declarative range partitions on `created_at` without schema changes to
  consumers.
- Full-text / semantic search can be layered on (`tsvector` columns or a vector
  column) without altering existing relationships.
