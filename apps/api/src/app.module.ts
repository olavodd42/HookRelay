import { randomUUID } from 'node:crypto';
import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { DatabaseService } from './shared/database.service';
import { HealthController } from './health.controller';

@Module({
  imports: [
    LoggerModule.forRoot({
      pinoHttp: {
        genReqId: (req, res) => {
          // read the received header
          const incoming = req.headers['x-request-id'];
          /*
            * POST /webhooks HTTP/1.1
            * Host: localhost:3000
            * x-request-id: pedido-123
          */

          // Validate the received header and use it if valid, otherwise generate a new one
          const id = typeof incoming === 'string' && /^[\w-]{1,64}$/.test(incoming) ? incoming : randomUUID();

          // Returns the id to the client in the response header and also returns it to pino for logging
          res.setHeader('x-request-id', id);
          return id;
        },
        // Customize the log message to include the request id and redact sensitive information
        customProps: (req) => ({ request_id: req.id }),
        redact: ['req.headers.authorization', 'req.headers.cookie'],
      },
    }),
  ],
  // Register the HealthController and DatabaseService in the AppModule
  controllers: [HealthController],
  providers: [DatabaseService],
})
export class AppModule {}