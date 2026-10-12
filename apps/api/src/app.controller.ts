import {
  Controller,
  Get,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('ready')
  async getReadiness(): Promise<{ status: string }> {
    if (!(await this.appService.isDatabaseReady())) {
      throw new ServiceUnavailableException('database is not ready');
    }

    return { status: 'ready' };
  }
}
