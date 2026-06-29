import Fastify, { type FastifyInstance, type FastifyError } from 'fastify';
import { ZodError } from 'zod';
import type { Database } from './db.js';
import { registerHealthRoutes } from './routes/health.js';
import { registerTaxonomyRoutes } from './routes/taxonomy.js';
import { registerProfessionalRoutes } from './routes/professionals.js';

export interface BuildOptions {
  db: Database;
  logger?: boolean | object;
}

/** Construct the Fastify app with all routes wired. Used by both the entry
 *  point and the test suite (which injects a test database). */
export function buildServer({ db, logger = false }: BuildOptions): FastifyInstance {
  const app = Fastify({ logger });

  // Translate validation failures into 400s with field detail.
  app.setErrorHandler((err: FastifyError, _req, reply) => {
    if (err instanceof ZodError) {
      return reply.status(400).send({
        error: 'invalid_request',
        issues: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      });
    }
    reply.log.error({ err }, 'unhandled error');
    return reply.status(err.statusCode ?? 500).send({ error: 'internal_error' });
  });

  registerHealthRoutes(app, db);
  registerTaxonomyRoutes(app, db);
  registerProfessionalRoutes(app, db);

  return app;
}
