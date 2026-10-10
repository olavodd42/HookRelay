import { Module } from '@nestjs/common';
import { createObserveModule } from '@nestjs/observe';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './modules/auth/auth.module';
import { ProjectsModule } from './modules/projects/projects.module';
import { EndpointsModule } from './modules/endpoints/endpoints.module';
import { EventsModule } from './modules/events/events.module';
import { DeliveriesModule } from './modules/deliveries/deliveries.module';
import { WorkerModule } from './modules/worker/worker.module';
import { SharedModule } from './modules/shared/shared.module';

export const { ObserveModule, ObserveInstrument } = createObserveModule();

@Module({
  imports: [
    // Distributed tracing, auto-correlated logs, request/job metrics, error
    // telemetry, alarms, and more — out of the box. Sign up at https://observe.nestjs.com
    ObserveModule.forRoot({
      appKey: 'YOUR_APP_KEY',
      appSecret: 'YOUR_APP_SECRET',
      serviceId: 'api',
    }),
    AuthModule,
    ProjectsModule,
    EndpointsModule,
    EventsModule,
    DeliveriesModule,
    WorkerModule,
    SharedModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
