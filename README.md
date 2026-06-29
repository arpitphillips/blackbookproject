# blackbookproject

The canonical structured database of the creative industry — a platform for
discovering, evaluating, and connecting creative professionals.

This repository starts where the [product specification](#specification) says
value lives: **the database is the product.** The first deliverable is a
complete, normalized, platform-agnostic PostgreSQL schema modeling the entire
domain — built to run on PostgreSQL today and to absorb the current Airtable +
forms.app stack via migration, with no Airtable-specific assumptions.

## What's here

```
db/
  migrations/        11 ordered DDL files (001 → 011, incl. views + intake)
  build.sql          builds the whole schema in dependency order
  seed.sql           minimal, idempotent reference + demo data
  ci/checks.sql      structural invariants asserted in CI
  supabase/rls.sql   Supabase-only row-level-security (anon insert/read)
  README.md          how to build, verify, and extend the schema
services/
  api/               TypeScript/Node discovery API (Fastify + pg)
web/                 Alpha frontend: React onboarding form → Supabase
docs/
  ARCHITECTURE.md    how the schema realizes the 5-layer platform spec
  DATA_MODEL.md      table-by-table data dictionary (55 tables)
  ERD.md             entity-relationship diagrams (Mermaid)
  MIGRATION.md       Airtable → PostgreSQL migration strategy
  DECISIONS.md       architectural decision log
.github/workflows/   CI: schema, API, and web checks
```

## Alpha frontend

[`web/`](web) is the alpha: a branded **professional onboarding form** (Vite +
React + TypeScript) that writes submissions directly to **Supabase** (hosted
PostgreSQL running this repo's schema). The browser uses the public anon key
under row-level security — it can submit onboarding data and read taxonomy for
dropdowns, nothing else. See [web/README.md](web/README.md) for Supabase setup.

## Discovery API

The first application layer — the spec's "primary experience" — lives in
[`services/api`](services/api): a TypeScript/Node service (Fastify + `pg`) that
exposes structured directory search, faceted filtering, and profile detail over
the schema, recording every query to `search_logs`/`search_impressions` for the
analytics and recommendation layers. See [services/api/README.md](services/api/README.md).

## Quick start

Requires PostgreSQL 14+ (validated on 16).

```bash
createdb blackbook
psql blackbook -v ON_ERROR_STOP=1 -f db/build.sql   # create schema
psql blackbook -v ON_ERROR_STOP=1 -f db/seed.sql    # load reference + demo data
```

## Design at a glance

- **Normalized & structured.** Everything searchable/filterable (category,
  profession, specialization, industry, service, location, language, equipment,
  client, tag, keyword) is a relational entity linked by UUID — never free text.
- **Five layers, one model.** Public discovery, professional portal,
  recommendation, communication, and monetization all read from one schema. See
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Tunable without deploys.** Recommendation weights
  (`ranking_factor_weights`), taxonomy, plans, and promotion products are data,
  not code.
- **Built to evolve.** Future-product tables (reviews, projects, messages,
  bookings, payments, collaborations) exist now so those features need no
  structural redesign; high-volume event tables are partition-ready; semantic
  search can be layered on without breaking relationships.
- **Migration-ready.** UUID keys + `external_ref` bridge make an Airtable →
  PostgreSQL cut a data migration, not a re-architecture. See
  [docs/MIGRATION.md](docs/MIGRATION.md).

## Verified

The schema builds clean on PostgreSQL 16, the seed is idempotent, and every
foreign key has a supporting index (55 tables, 28 enum types).

## Specification

The full product vision lives in
[docs/SPECIFICATION.md](docs/SPECIFICATION.md). In short: this is a structured
data and discovery engine, not a portfolio site, marketplace, or social network.
Profiles are the interface; search is the experience; recommendations are the
differentiator; trust is the moat; monetization is built on visibility and
relevance, never on restricting discovery.
