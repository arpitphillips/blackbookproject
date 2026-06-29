import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Database } from '../db.js';
import {
  searchProfessionals,
  getProfessionalBySlug,
  recordSearch,
  incrementProfileView,
} from '../repositories/professionals.js';

const slug = z.string().min(1).max(255);
const boolish = z
  .enum(['true', 'false', '1', '0'])
  .transform((v) => v === 'true' || v === '1');

const searchQuery = z.object({
  q: z.string().min(1).max(200).optional(),
  category: slug.optional(),
  profession: slug.optional(),
  specialization: slug.optional(),
  industry: slug.optional(),
  service: slug.optional(),
  location: slug.optional(),
  language: z.string().min(1).max(12).optional(),
  availability: z.enum(['available', 'limited', 'unavailable', 'booked']).optional(),
  verified: boolish.optional(),
  featured: boolish.optional(),
  minExperience: z.coerce.number().int().min(0).max(100).optional(),
  sort: z.enum(['featured', 'quality', 'experience', 'recent', 'name']).default('featured'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

const detailParams = z.object({ slug });

export function registerProfessionalRoutes(app: FastifyInstance, db: Database): void {
  // Directory search & filtering.
  app.get('/api/professionals', async (req) => {
    const params = searchQuery.parse(req.query);
    const result = await searchProfessionals(db, params);

    // Fire-and-forget analytics; never let it affect the response.
    const { page, pageSize, sort, ...filters } = params;
    recordSearch(db, {
      query: params.q,
      filters,
      resultCount: result.total,
      items: result.items as { id: unknown }[],
    }).catch((err) => req.log.warn({ err }, 'failed to record search'));

    return result;
  });

  // Public profile detail by slug.
  app.get('/api/professionals/:slug', async (req, reply) => {
    const { slug: profileSlug } = detailParams.parse(req.params);
    const profile = await getProfessionalBySlug(db, profileSlug);
    if (!profile) {
      return reply.status(404).send({ error: 'not_found' });
    }
    incrementProfileView(db, profile.id).catch((err) =>
      req.log.warn({ err }, 'failed to increment view'),
    );
    return profile;
  });
}
