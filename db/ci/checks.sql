-- =============================================================================
-- ci/checks.sql  -  Post-build invariants asserted in CI.
-- Run after build.sql + seed.sql. Each check RAISEs on violation so that, with
-- `psql -v ON_ERROR_STOP=1`, any failure fails the job. Invariants are
-- structural (not hard-coded counts) so they keep holding as the schema grows.
-- =============================================================================
\set ON_ERROR_STOP on

-- 1. Required extensions are installed.
DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(e, ', ') INTO missing
    FROM unnest(ARRAY['pgcrypto','citext','pg_trgm']) AS e
    WHERE e NOT IN (SELECT extname FROM pg_extension);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required extension(s): %', missing;
    END IF;
END $$;

-- 2. Every single-column foreign key has a supporting index (our stated policy).
DO $$
DECLARE n int; offenders text;
BEGIN
    SELECT count(*), string_agg(format('%s.%s', c.conrelid::regclass, a.attname), ', ')
      INTO n, offenders
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.contype = 'f' AND array_length(c.conkey, 1) = 1
      AND NOT EXISTS (
          SELECT 1 FROM pg_index i
          WHERE i.indrelid = c.conrelid AND c.conkey[1] = i.indkey[0]
      );
    IF n > 0 THEN
        RAISE EXCEPTION 'Found % unindexed single-column foreign key(s): %', n, offenders;
    END IF;
END $$;

-- 3. Every mutable table (has updated_at) has its set_updated_at trigger wired.
DO $$
DECLARE n int; offenders text;
BEGIN
    SELECT count(*), string_agg(c.relname, ', ')
      INTO n, offenders
    FROM pg_class c
    JOIN pg_namespace ns ON ns.oid = c.relnamespace AND ns.nspname = 'public'
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'updated_at' AND NOT a.attisdropped
    WHERE c.relkind = 'r'
      AND NOT EXISTS (
          SELECT 1 FROM pg_trigger t
          WHERE t.tgrelid = c.oid AND NOT t.tgisinternal
            AND t.tgname LIKE 'trg_%_updated'
      );
    IF n > 0 THEN
        RAISE EXCEPTION 'Table(s) with updated_at but no set_updated_at trigger: %', offenders;
    END IF;
END $$;

-- 4. Seed produced a working end-to-end directory listing.
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n
    FROM professional_profiles p
    JOIN profile_categories  pc ON pc.profile_id = p.id AND pc.is_primary
    JOIN profile_professions pp ON pp.profile_id = p.id AND pp.is_primary
    WHERE p.status = 'approved';
    IF n < 1 THEN
        RAISE EXCEPTION 'Expected >=1 approved, fully-linked profile from seed, found %', n;
    END IF;
END $$;

\echo 'All CI schema invariants passed.'
