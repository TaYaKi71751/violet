import { Test, TestingModule } from '@nestjs/testing';
import { ViewService } from './view.service';
import { RedisService } from '../redis/redis.service';
import { ViewRepository } from './view.repository';
import { ViewGetRequestDto } from './dtos/view-get.dto';
import { ViewPostRequestDto } from './dtos/view-post.dto';
import { User } from '../user/entity/user.entity';

describe('ViewService', () => {
  let service: ViewService;
  let redisService: RedisService;
  let viewRepository: ViewRepository;

  // Redis 서비스 모킹
  const mockRedisService = {
    zrevrange_by_score: jest.fn(),
    zincrby: jest.fn(),
    setex: jest.fn(),
  };

  // ViewRepository 모킹
  const mockViewRepository = {
    postView: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ViewService,
        {
          provide: RedisService,
          useValue: mockRedisService,
        },
        {
          provide: ViewRepository,
          useValue: mockViewRepository,
        },
      ],
    }).compile();

    service = module.get<ViewService>(ViewService);
    redisService = module.get<RedisService>(RedisService);
    viewRepository = module.get<ViewRepository>(ViewRepository);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getView', () => {
    it('조회수 데이터를 정상적으로 가져와야 합니다', async () => {
      const mockDto: ViewGetRequestDto = {
        type: 'daily',
        offset: 0,
        count: 10,
      };

      // Redis에서 반환될 mock 데이터
      const mockRedisResponse = ['1', '100', '2', '50', '3', '25'];
      mockRedisService.zrevrange_by_score.mockResolvedValue(mockRedisResponse);

      const result = await service.getView(mockDto);

      expect(result).toEqual({
        elements: [
          { articleId: 1, count: 100 },
          { articleId: 2, count: 50 },
          { articleId: 3, count: 25 },
        ],
      });

      expect(redisService.zrevrange_by_score).toHaveBeenCalledWith(
        'daily',
        0,
        10,
      );
    });

    it('type이 없을 경우 기본값으로 daily를 사용해야 합니다', async () => {
      const mockDto: ViewGetRequestDto = {
        offset: 0,
        count: 10,
      };

      mockRedisService.zrevrange_by_score.mockResolvedValue([]);

      await service.getView(mockDto);

      expect(redisService.zrevrange_by_score).toHaveBeenCalledWith(
        'daily',
        0,
        10,
      );
    });
  });

  describe('post', () => {
    it('비로그인 사용자의 조회수를 정상적으로 처리해야 합니다', () => {
      const mockDto: ViewPostRequestDto = {
        articleId: 1,
        viewSeconds: 10,
        userAppId: 'testUser',
      };

      service.post(mockDto);

      expect(viewRepository.postView).toHaveBeenCalledWith(mockDto);
      expect(redisService.zincrby).toHaveBeenCalled();
    });
  });

  describe('postLogined', () => {
    it('로그인 사용자의 조회수를 정상적으로 처리해야 합니다', async () => {
      const mockUser = { id: 1 } as User;
      const mockDto: ViewPostRequestDto = {
        articleId: 1,
        viewSeconds: 10,
        userAppId: 'testUser',
      };

      await service.postLogined(mockUser, mockDto);

      expect(redisService.zincrby).toHaveBeenCalled();
    });
  });

  describe('postRedis', () => {
    it('Redis에 조회수 데이터를 정상적으로 저장해야 합니다', () => {
      const articleId = 1;
      jest.spyOn(global.Date, 'now').mockImplementation(() => 1234567890);

      service.postRedis(articleId);

      // alltime 조회수 증가 확인
      expect(redisService.zincrby).toHaveBeenCalledWith('alltime', 1, articleId);

      // daily 조회수 증가 및 만료시간 설정 확인
      expect(redisService.zincrby).toHaveBeenCalledWith('daily', 1, articleId);
      expect(redisService.setex).toHaveBeenCalledWith(
        expect.stringContaining('daily-'),
        24 * 60 * 60,
        '1',
      );

      // weekly 조회수 증가 및 만료시간 설정 확인
      expect(redisService.zincrby).toHaveBeenCalledWith('weekly', 1, articleId);
      expect(redisService.setex).toHaveBeenCalledWith(
        expect.stringContaining('weekly-'),
        7 * 24 * 60 * 60,
        '1',
      );

      // monthly 조회수 증가 및 만료시간 설정 확인
      expect(redisService.zincrby).toHaveBeenCalledWith('monthly', 1, articleId);
      expect(redisService.setex).toHaveBeenCalledWith(
        expect.stringContaining('monthly-'),
        30 * 24 * 60 * 60,
        '1',
      );
    });
  });
});
