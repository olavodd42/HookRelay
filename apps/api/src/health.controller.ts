import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from './shared/database.service';

@Controller()
export class HealthController {
  constructor(private readonly db: DatabaseService) {}

  @Get('health')   // liveness: the proccess responds
  health() {
    return { status: 'ok' };
  }

  @Get('ready')    // readiness: the database responds
  async ready() {
    try {
      await this.db.ping();
      return { status: 'ok' };
    } catch {
      throw new ServiceUnavailableException({ status: 'database_unavailable' });
    }
  }
}