import type { FastifyInstance } from 'fastify';
import type { Database } from '../db.js';

export function registerHealthRoutes(app: FastifyInstance, db: Database): void {
  // Liveness: process is up.
  app.get('/health', async () => ({ status: 'ok' }));

  // Readiness: database is reachable.
  app.get('/health/ready', async (_req, reply) => {
    try {
      await db.query('SELECT 1');
      return { status: 'ready' };
    } catch {
      return reply.status(503).send({ status: 'unavailable' });
    }
  });
}
