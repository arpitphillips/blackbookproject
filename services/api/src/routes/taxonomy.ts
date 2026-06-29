import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Database } from '../db.js';
import { listCategories, listProfessions, listLocations } from '../repositories/taxonomy.js';

const categoriesQuery = z.object({ parent: z.string().min(1).optional() });
const professionsQuery = z.object({ category: z.string().min(1).optional() });
const locationsQuery = z.object({
  type: z.enum(['country', 'state', 'region', 'city', 'area', 'neighborhood']).optional(),
});

export function registerTaxonomyRoutes(app: FastifyInstance, db: Database): void {
  app.get('/api/categories', async (req) => {
    const { parent } = categoriesQuery.parse(req.query);
    return { items: await listCategories(db, parent) };
  });

  app.get('/api/professions', async (req) => {
    const { category } = professionsQuery.parse(req.query);
    return { items: await listProfessions(db, category) };
  });

  app.get('/api/locations', async (req) => {
    const { type } = locationsQuery.parse(req.query);
    return { items: await listLocations(db, type) };
  });
}
