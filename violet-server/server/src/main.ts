import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './common/utils/swagger';
import { logger } from './common/utils/logger';
import * as cookies from 'cookie-parser';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: logger });

  app.setGlobalPrefix('api/v2');
  app.useGlobalPipes(new ValidationPipe());
  app.use(cookies());

  // CORS 설정 추가
  app.enableCors({
    origin: true, // 모든 출처에서의 요청을 허용
    credentials: true, // 쿠키와 인증 헤더를 포함한 요청 허용
  });

  setupSwagger(app);

  await app.listen(3000);
}
bootstrap();
