import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createDatabase, type Database } from '../src/db.js';
import { buildServer } from '../src/server.js';

// Integration tests run only when a database is provided. CI (and the local
// `npm test` documented in the README) build + seed the schema first, then set
// DATABASE_URL. Without it, these are skipped so unit tests still run anywhere.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('API (integration)', () => {
  let db: Database;
  let app: FastifyInstance;

  beforeAll(async () => {
    db = createDatabase(url!);
    app = buildServer({ db });
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
    await db.close();
  });

  it('GET /health -> ok', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ok' });
  });

  it('GET /health/ready -> reaches the database', async () => {
    const res = await app.inject({ method: 'GET', url: '/health/ready' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ready' });
  });

  it('lists the seeded demo professional', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals' });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.total).toBeGreaterThanOrEqual(1);
    const slugs = body.items.map((i: { slug: string }) => i.slug);
    expect(slugs).toContain('demo-professional');
  });

  it('filters by category facet', async () => {
    const hit = await app.inject({ method: 'GET', url: '/api/professionals?category=photography' });
    expect(hit.json().total).toBeGreaterThanOrEqual(1);

    const miss = await app.inject({ method: 'GET', url: '/api/professionals?category=does-not-exist' });
    expect(miss.json().total).toBe(0);
    expect(miss.json().items).toEqual([]);
  });

  it('filters by verification (demo is unverified -> no results)', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals?verified=true' });
    expect(res.json().total).toBe(0);
  });

  it('paginates with total and pageCount', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals?pageSize=1' });
    const body = res.json();
    expect(body.pageSize).toBe(1);
    expect(body.items.length).toBeLessThanOrEqual(1);
    expect(body.pageCount).toBe(Math.ceil(body.total / 1));
  });

  it('rejects invalid query params with 400', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals?pageSize=500' });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe('invalid_request');
  });

  it('returns full profile detail by slug', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals/demo-professional' });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.display_name).toBe('Demo Professional');
    expect(body.categories.map((c: { slug: string }) => c.slug)).toContain('photography');
    expect(body.availability).not.toBeNull();
    expect(Array.isArray(body.portfolio)).toBe(true);
  });

  it('404s an unknown profile slug', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/professionals/nope-not-here' });
    expect(res.statusCode).toBe(404);
  });

  it('serves taxonomy for filter UIs', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/categories' });
    expect(res.statusCode).toBe(200);
    expect(res.json().items.map((c: { slug: string }) => c.slug)).toContain('photography');
  });
});
