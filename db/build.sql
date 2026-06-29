-- =============================================================================
-- build.sql  -  Build the entire schema from scratch, in dependency order.
-- Usage:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/build.sql
-- (Run from the repository root so the relative \i paths resolve.)
-- =============================================================================
\set ON_ERROR_STOP on

\echo '== 001 extensions & enums =='
\i db/migrations/001_extensions_enums.sql
\echo '== 002 taxonomy =='
\i db/migrations/002_taxonomy.sql
\echo '== 003 users & profiles =='
\i db/migrations/003_users_profiles.sql
\echo '== 004 profile relations =='
\i db/migrations/004_profile_relations.sql
\echo '== 005 engagement & recommendation =='
\i db/migrations/005_engagement.sql
\echo '== 006 monetization =='
\i db/migrations/006_monetization.sql
\echo '== 007 communication =='
\i db/migrations/007_communication.sql
\echo '== 008 future products =='
\i db/migrations/008_future.sql
\echo '== 009 supporting indexes =='
\i db/migrations/009_supporting_indexes.sql
\echo '== 010 read-model views =='
\i db/migrations/010_views.sql
\echo '== schema build complete =='
