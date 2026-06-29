import pg from 'pg';

const { Pool } = pg;

/**
 * Thin wrapper over a pg connection pool. The query layer stays close to SQL
 * (parameterized, no ORM) so it maps directly onto the schema and views and
 * remains portable if the database is swapped later.
 */
export interface Database {
  query<T extends pg.QueryResultRow = pg.QueryResultRow>(
    text: string,
    params?: readonly unknown[],
  ): Promise<pg.QueryResult<T>>;
  close(): Promise<void>;
}

export function createDatabase(connectionString: string): Database {
  const pool = new Pool({ connectionString });
  return {
    query: (text, params) => pool.query(text, params as unknown[] | undefined),
    close: () => pool.end(),
  };
}
