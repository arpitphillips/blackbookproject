import { loadConfig } from './config.js';
import { createDatabase } from './db.js';
import { buildServer } from './server.js';

const config = loadConfig();
const db = createDatabase(config.databaseUrl);
const app = buildServer({
  db,
  logger: { level: config.logLevel },
});

async function start(): Promise<void> {
  try {
    await app.listen({ port: config.port, host: config.host });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    void app.close().then(() => db.close()).finally(() => process.exit(0));
  });
}

void start();
