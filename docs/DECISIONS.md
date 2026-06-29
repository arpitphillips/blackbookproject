# Decision Record

Lightweight log of architectural decisions. Newest last.

## D1 — Relational PostgreSQL schema as the foundation

**Status:** Accepted · merged in #1

The spec states "the database is the product" and requires a normalized,
platform-agnostic model that can migrate off Airtable to PostgreSQL with minimal
redesign. We therefore built the data foundation first as plain PostgreSQL DDL
(no Airtable-specific assumptions): UUID keys, explicit junction tables, taxonomy
as first-class entities, enums for lifecycle states, tables for admin-managed
config. See [ARCHITECTURE.md](./ARCHITECTURE.md) and [DATA_MODEL.md](./DATA_MODEL.md).

## D2 — CI gate for the schema

**Status:** Accepted

`.github/workflows/db.yml` runs on every PR/`main` push that touches `db/`: it
spins up PostgreSQL 16, runs `db/build.sql`, loads `db/seed.sql`, re-runs the
seed to prove idempotency, and executes `db/ci/checks.sql` (structural
invariants: required extensions present, no unindexed single-column FKs, every
`updated_at` table has its trigger, seed yields a working directory listing).
This turns the previously-manual local validation into an automated gate.

## D3 — Backend stack: TypeScript / Node

**Status:** Accepted

The spec fixes the frontend as "platform-agnostic" but leaves the backend open.
For application code (discovery/search API, forms.app onboarding ingestion,
recommendation scorer) we will use **TypeScript on Node.js**. Rationale:
end-to-end type safety shared with a future TS frontend, a broad ecosystem, and
mature typed PostgreSQL access. Specific libraries (query builder / driver,
web framework) will be chosen when the first service is scaffolded.

## D4 — Alpha: Supabase as the operational store + a React onboarding form

**Status:** Accepted

For the alpha the deliverable is a frontend with an onboarding form whose data
lands in a database. We chose **Supabase** over Airtable because Supabase *is*
hosted PostgreSQL, so the existing `db/` schema becomes the operational database
as-is, and the browser can write securely with the public **anon** key under
row-level security — no server required for the alpha.

- The form (`web/`, Vite + React + TS) writes to `public.onboarding_submissions`
  (migration 011): a denormalized, FK-free intake table. A back-office step
  later promotes reviewed submissions into `users` + `professional_profiles`.
- RLS (`db/supabase/rls.sql`, applied only on Supabase) grants anon **INSERT**
  on submission data columns (not `status`) and **SELECT** on active taxonomy
  for dropdowns — nothing else. Server code uses the service-role key.
- The portable schema and CI stay vanilla-PostgreSQL clean; Supabase-specific
  SQL is isolated under `db/supabase/`.

If the platform must later standardize on Airtable, the Node API (`services/api`)
is the natural place for a server-side Airtable writer; the intake table and
form remain unchanged.
