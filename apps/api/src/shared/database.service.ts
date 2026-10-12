import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';
import { env } from '../config/env';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool = new Pool({
    connectionString: env.DATABASE_URL,
    max: 10,
    connectionTimeoutMillis: 2000,
  });

  async ping(): Promise<void> {
    await this.pool.query('SELECT 1');
  }

  onModuleDestroy() {
    return this.pool.end();
  }
}