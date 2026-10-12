import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { env } from './config/env';

async function bootstrap() {
  /*
    * Initializes the NestJS application.
  */
  
  // Create a NestJS application using the AppModule and stores temporarily buffered logs until the logger is set up
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // Set up the logger for the application using the Logger service from nestjs-pino
  app.useLogger(app.get(Logger));

  // Use Helmet middleware to enhance security by setting various HTTP headers
  app.use(helmet());

  // Enable shutdown hooks to allow the application to respond to termination signals gracefully
  app.enableShutdownHooks(); // essential to the worker on Phase 5

  // Start the application and listen on the port specified in the environment configuration
  await app.listen(env.PORT);
}
bootstrap();