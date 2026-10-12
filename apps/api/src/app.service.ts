import { Injectable } from '@nestjs/common';
import { createConnection } from 'node:net';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
  }

  async isDatabaseReady(): Promise<boolean> {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      return false;
    }

    let url: URL;
    try {
      url = new URL(databaseUrl);
    } catch {
      return false;
    }

    return new Promise((resolve) => {
      const socket = createConnection({
        host: url.hostname,
        port: Number(url.port) || 5432,
      });
      const finish = (ready: boolean) => {
        socket.destroy();
        resolve(ready);
      };

      socket.setTimeout(1000);
      socket.once('connect', () => finish(true));
      socket.once('error', () => finish(false));
      socket.once('timeout', () => finish(false));
    });
  }
}
