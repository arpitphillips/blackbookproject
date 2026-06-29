# Web (alpha)

The alpha frontend for the Creative Professionals Platform: a branded
**professional onboarding form** that writes submissions directly to
**Supabase**. Vite + React + TypeScript.

The form's data lands in `public.onboarding_submissions` (see
[../db/migrations/011_onboarding.sql](../db/migrations/011_onboarding.sql)).
The browser uses the Supabase **anon** key; row-level security
([../db/supabase/rls.sql](../db/supabase/rls.sql)) lets it INSERT submissions
and READ active taxonomy for the dropdowns — nothing else. A back-office process
promotes reviewed submissions into full profiles.

> Field set is derived from the master spec's onboarding steps and is
> intentionally easy to change: edit `src/types.ts` (the form shape) and
> `src/OnboardingForm.tsx` (the sections). The matching database columns live in
> migration 011.

## Setup

1. **Create a Supabase project**, then in the SQL editor (or via `psql` against
   the project's connection string) run, in order:
   ```bash
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f ../db/build.sql
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f ../db/seed.sql        # optional reference data
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f ../db/supabase/rls.sql
   ```
2. **Configure env**: copy `.env.example` to `.env.local` and fill in the
   project URL and anon key (Project Settings → API). Both are public values.
3. **Run**:
   ```bash
   npm install
   npm run dev        # http://localhost:5173
   ```

Without env configured the form runs in **demo mode**: dropdowns use built-in
fallback options and submissions are not saved (a banner makes this clear).

## Scripts

| Script | Purpose |
| --- | --- |
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | Typecheck + production build to `dist/` |
| `npm run preview` | Serve the production build locally |
| `npm run typecheck` | TypeScript, no emit |

## Deploy

`npm run build` produces a static `dist/` deployable to any static host
(Vercel, Netlify, Cloudflare Pages, S3…). Set `VITE_SUPABASE_URL` and
`VITE_SUPABASE_ANON_KEY` as build-time env vars on the host.

## Layout

```
index.html
src/
  main.tsx            React entry
  App.tsx             hero + page shell
  OnboardingForm.tsx  the form (sections, validation, submit)
  taxonomy.ts         loads dropdown options from Supabase (with fallback)
  supabaseClient.ts   env-guarded anon client
  types.ts            form shape + empty state
  styles.css          styling
```
