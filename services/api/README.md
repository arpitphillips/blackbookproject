# Discovery API

The directory **search & discovery API** for the Creative Professionals
Platform — the spec's "primary experience." A small TypeScript/Node service
(Fastify + `pg`) that reads the [database](../../db) and exposes structured
search, filtering, and profile detail over HTTP.

Per [docs/DECISIONS.md](../../docs/DECISIONS.md) D3, the stack is TypeScript on
Node. Data access is plain parameterized SQL (no ORM) so it maps directly onto
the schema and views and stays portable.

## Endpoints

| Method & path | Purpose |
| --- | --- |
| `GET /health` | Liveness. |
| `GET /health/ready` | Readiness (database reachable). |
| `GET /api/professionals` | Directory search + filters + pagination. |
| `GET /api/professionals/:slug` | Full public profile detail. |
| `GET /api/categories` | Categories (optionally `?parent=<slug>`). |
| `GET /api/professions` | Professions (optionally `?category=<slug>`). |
| `GET /api/locations` | Locations (optionally `?type=country\|state\|city\|…`). |

### Search parameters (`GET /api/professionals`)

`q` (name/headline/studio text), `category`, `profession`, `specialization`,
`industry`, `service`, `location` (base or area served), `language` (code),
`availability` (`available`|`limited`|`unavailable`|`booked`), `verified`
(bool), `featured` (bool), `minExperience` (int), `sort`
(`featured`|`quality`|`experience`|`recent`|`name`, default `featured`), `page`
(default 1), `pageSize` (default 20, max 100).

Response: `{ items, total, page, pageSize, pageCount }`. Each search is recorded
to `search_logs` + `search_impressions` (best-effort) so the analytics and
recommendation layers have signal from day one.

```bash
curl 'http://localhost:3000/api/professionals?category=photography&location=mumbai&sort=quality'
curl 'http://localhost:3000/api/professionals/demo-professional'
```

## Run locally

Requires Node 20+ and a running platform database (see [../../db](../../db)).

```bash
cp .env.example .env          # point DATABASE_URL at your database
npm install
npm run dev                   # watch mode on http://localhost:3000
```

## Test

Unit tests (query builder) run with no database. Integration tests run when
`DATABASE_URL` is set against a freshly built + seeded database:

```bash
# from the repo root, with a database available:
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/build.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/seed.sql
cd services/api && npm install && npm test
```

`npm run typecheck` runs the TypeScript compiler in no-emit mode. CI
(`.github/workflows/api.yml`) does typecheck + unit + integration on every PR.

## Layout

```
src/
  index.ts                 entry point (listen + graceful shutdown)
  server.ts                Fastify app assembly + error handling
  config.ts                env-driven config
  db.ts                    pg pool wrapper
  search/query.ts          pure, injection-safe search SQL builder
  repositories/            data access (professionals, taxonomy)
  routes/                  HTTP routes + zod validation
test/
  query.test.ts            unit tests for the search builder (no DB)
  api.test.ts              integration tests (skipped without DATABASE_URL)
```
