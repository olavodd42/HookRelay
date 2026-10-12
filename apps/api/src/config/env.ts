import { resolve } from 'node:path';
import { config } from 'dotenv';
import { z } from 'zod';

config({
  path: [
    resolve(process.cwd(), '.env'),
    resolve(__dirname, '../../../.env'),
    resolve(__dirname, '../../../../.env'),
  ],
});

const bool = z.enum(['true', 'false']).default('false').transform((v) => v === 'true');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  ALLOW_HTTP_ENDPOINTS: bool,
  SSRF_ALLOW_PRIVATE: bool,
});

export const env = schema.parse(process.env);

if (env.NODE_ENV === 'production' && (env.ALLOW_HTTP_ENDPOINTS || env.SSRF_ALLOW_PRIVATE)) {
  throw new Error('Flags de desenvolvimento ativas em produção');
}