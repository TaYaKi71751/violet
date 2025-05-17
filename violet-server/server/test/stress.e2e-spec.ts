import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { UserRegisterDTO } from 'src/user/dtos/user-register.dto';
import { CommentPostDto } from 'src/comment/dtos/comment-post.dto';
import * as cookieParser from 'cookie-parser';
import { ValidationPipe } from '@nestjs/common';
import { UserRepository } from 'src/user/user.repository';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CommentRepository } from 'src/comment/comment.repository';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from 'src/user/entity/user.entity';
import { Comment } from 'src/comment/entity/comment.entity';
import { View } from 'src/view/entity/view.entity';

describe('Stress Test (e2e)', () => {
    let app: INestApplication;
    let authToken: string;
    let userRepository: UserRepository;
    let commentRepository: CommentRepository;
    const TEST_USER_ID = 'abcdefghijklmnopqrstuvwxyz0123456789ABCD';  // 40자의 영숫자 조합

    beforeAll(async () => {
        const moduleFixture: TestingModule = await Test.createTestingModule({
            imports: [
                TypeOrmModule.forRoot({
                    type: 'sqlite',
                    database: ':memory:',
                    entities: [User, Comment, View],
                    synchronize: true,
                    logging: false,  // 로깅 비활성화
                }),
                AppModule
            ],
        })
            .overrideGuard(HmacAuthGuard)
            .useValue({ canActivate: jest.fn(() => true) })
            .compile();

        app = moduleFixture.createNestApplication();
        userRepository = moduleFixture.get<UserRepository>(UserRepository);
        commentRepository = moduleFixture.get<CommentRepository>(CommentRepository);

        // 앱 설정
        app.use(cookieParser());
        app.useGlobalPipes(new ValidationPipe());
        app.setGlobalPrefix('api/v2');  // API 버전 prefix 설정

        await app.init();

        // 테스트 유저 생성
        const user = await userRepository.createUser({
            userAppId: TEST_USER_ID
        });

        if (!user || !user.userAppId) {
            throw new Error('사용자 생성에 실패했습니다');
        }

        // 테스트용 사용자 로그인
        const loginResponse = await request(app.getHttpServer())
            .post('/api/v2/auth')
            .send({
                userAppId: TEST_USER_ID,
            } as UserRegisterDTO);

        console.log('Login Response:', {
            status: loginResponse.status,
            headers: loginResponse.headers,
            body: loginResponse.body
        });

        // 쿠키에서 토큰 추출
        const cookieHeader = loginResponse.headers['set-cookie'];
        if (!cookieHeader || !Array.isArray(cookieHeader)) {
            throw new Error('No cookies received');
        }
        console.log('Cookies:', cookieHeader);

        // jwt-access 쿠키 찾기
        const accessTokenCookie = cookieHeader.find(cookie => cookie.startsWith('jwt-access='));
        if (!accessTokenCookie) {
            throw new Error('Access token cookie not found');
        }

        // 쿠키 값 추출
        authToken = accessTokenCookie.split(';')[0].replace('jwt-access=', '');
    });

    describe('Auth Stress Test', () => {
        it('should handle multiple concurrent login requests', async () => {
            const numberOfRequests = 20;
            const batchSize = 5;

            // 먼저 테스트 유저들을 생성
            for (let i = 0; i < numberOfRequests; i++) {
                const userAppId = `test${(i + 1000).toString().padStart(36, '0')}`;
                await userRepository.createUser({
                    userAppId: userAppId
                });
            }

            const results = [];
            for (let i = 0; i < numberOfRequests; i += batchSize) {
                const batch = Array(Math.min(batchSize, numberOfRequests - i))
                    .fill(null)
                    .map((_, index) =>
                        request(app.getHttpServer())
                            .post('/api/v2/auth')
                            .send({
                                userAppId: `test${(i + index + 1000).toString().padStart(36, '0')}`,
                            } as UserRegisterDTO)
                    );

                const batchResults = await Promise.all(batch);
                results.push(...batchResults);
                await new Promise(resolve => setTimeout(resolve, 100));
            }

            // 검증
            results.forEach(response => {
                if (response.status < 200 || response.status >= 400) {
                    console.log('Failed response:', response.body);
                }
                expect(response.status).toBeGreaterThanOrEqual(200);
                expect(response.status).toBeLessThan(400);

                const cookieHeader = response.headers['set-cookie'];
                expect(cookieHeader).toBeDefined();
                expect(Array.isArray(cookieHeader)).toBe(true);
                if (Array.isArray(cookieHeader)) {
                    expect(cookieHeader.length).toBeGreaterThan(0);
                    expect(cookieHeader.some(cookie => cookie.startsWith('jwt-access='))).toBe(true);
                }
            });
        });
    });

    describe('Comment Stress Test', () => {
        it('should handle multiple concurrent comment posts', async () => {
            const numberOfComments = 20;
            const batchSize = 5;

            const results = [];
            for (let i = 0; i < numberOfComments; i += batchSize) {
                const batch = Array(Math.min(batchSize, numberOfComments - i))
                    .fill(null)
                    .map((_, index) =>
                        request(app.getHttpServer())
                            .post('/api/v2/comment')
                            .set('Cookie', [`jwt-access=${authToken}`])  // 변경: Bearer 토큰 대신 쿠키 사용
                            .send({
                                where: 'general',
                                body: `Stress test comment ${i + index}`,
                            } as CommentPostDto)
                    );

                const batchResults = await Promise.all(batch);
                results.push(...batchResults);
                await new Promise(resolve => setTimeout(resolve, 100));
            }

            // 검증 수정
            results.forEach(response => {
                if (response.status !== 201) {
                    console.log('Failed response:', response.body);  // 실패 원인 로깅
                }
                expect(response.status).toBe(201);
                expect(response.body.ok).toBe(true);
            });
        });

        it('should handle concurrent comment reads and writes', async () => {
            const numberOfOperations = 20;
            const batchSize = 5;

            const results = [];
            for (let i = 0; i < numberOfOperations; i += batchSize) {
                const batch = Array(Math.min(batchSize, numberOfOperations - i))
                    .fill(null)
                    .map((_, index) => {
                        const isRead = (i + index) % 2 === 0;
                        return request(app.getHttpServer())
                        [isRead ? 'get' : 'post']('/api/v2/comment')
                            .set('Cookie', [`jwt-access=${authToken}`])
                            .send(isRead
                                ? { where: 'general' }
                                : {
                                    where: 'general',
                                    body: `Mixed operation comment ${i + index}`,
                                } as CommentPostDto
                            );
                    });

                const batchResults = await Promise.all(batch);
                results.push(...batchResults);
                await new Promise(resolve => setTimeout(resolve, 100));
            }

            // 검증 수정: GET과 POST 요청의 예상 상태 코드가 다름
            results.forEach((response, index) => {
                const isRead = index % 2 === 0;
                const expectedStatus = isRead ? 200 : 201;
                if (response.status !== expectedStatus) {
                    console.log('Failed response:', response.body);
                }
                expect(response.status).toBe(expectedStatus);
            });
        });
    });

    afterAll(async () => {
        await app.close();
    });
}); 