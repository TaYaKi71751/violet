import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRepository } from 'src/user/user.repository';
import { BadRequestException, HttpException } from '@nestjs/common';
import { User } from 'src/user/entity/user.entity';

describe('AuthService', () => {
  let service: AuthService;
  let userRepository: UserRepository;
  let jwtService: JwtService;
  let configService: ConfigService;

  const mockUserRepository = {
    findOneBy: jest.fn(),
    update: jest.fn(),
  };

  const mockJwtService = {
    sign: jest.fn(),
    signAsync: jest.fn(),
  };

  const mockConfigService = {
    get: jest.fn(),
  };


  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UserRepository,
          useValue: mockUserRepository,
        },
        {
          provide: JwtService,
          useValue: mockJwtService,
        },
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    userRepository = module.get<UserRepository>(UserRepository);
    jwtService = module.get<JwtService>(JwtService);
    configService = module.get<ConfigService>(ConfigService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('verifyUserAndSignJWT', () => {
    const mockUserDto = { userAppId: 'test123' };
    const mockUser = { userAppId: 'test123' } as User;
    const mockTokens = {
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    };

    it('사용자 검증 및 JWT 발급에 성공해야 합니다', async () => {
      mockUserRepository.findOneBy.mockResolvedValue(mockUser);
      jest.spyOn(service, 'createJWT').mockResolvedValue(mockTokens);
      jest.spyOn(service, 'updateRefreshToken').mockResolvedValue(undefined);

      const result = await service.verifyUserAndSignJWT(mockUserDto);

      expect(result).toEqual({ user: mockUser, tokens: mockTokens });
      expect(mockUserRepository.findOneBy).toHaveBeenCalledWith({
        userAppId: mockUserDto.userAppId,
      });
    });

    it('존재하지 않는 사용자일 경우 BadRequestException을 발생시켜야 합니다', async () => {
      mockUserRepository.findOneBy.mockResolvedValue(null);

      await expect(service.verifyUserAndSignJWT(mockUserDto)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('refreshTokens', () => {
    const mockRefreshToken = 'refresh-token';
    const mockUser = { userAppId: 'test123' } as User;
    const mockTokens = {
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
    };

    it('리프레시 토큰으로 새로운 토큰 발급에 성공해야 합니다', async () => {
      mockUserRepository.findOneBy.mockResolvedValue(mockUser);
      jest.spyOn(service, 'createJWT').mockResolvedValue(mockTokens);
      jest.spyOn(service, 'updateRefreshToken').mockResolvedValue(undefined);

      const result = await service.refreshTokens(mockRefreshToken);

      expect(result).toEqual({ tokens: mockTokens, user: mockUser });
      expect(mockUserRepository.findOneBy).toHaveBeenCalledWith({
        refreshToken: mockRefreshToken,
      });
    });

    it('유효하지 않은 리프레시 토큰일 경우 HttpException을 발생시켜야 합니다', async () => {
      mockUserRepository.findOneBy.mockResolvedValue(null);

      await expect(service.refreshTokens(mockRefreshToken)).rejects.toThrow(
        HttpException,
      );
    });
  });

  describe('updateDiscordInfo', () => {
    const mockUser = {
      userAppId: 'test123',
      discordId: 'discord123',
      avatar: 'avatar.png',
    } as User;

    it('디스코드 정보 업데이트에 성공해야 합니다', async () => {
      mockUserRepository.update.mockResolvedValue({ affected: 1 });

      const result = await service.updateDiscordInfo(mockUser);

      expect(result).toEqual({ ok: true });
      expect(mockUserRepository.update).toHaveBeenCalledWith(
        { userAppId: mockUser.userAppId },
        { discordId: mockUser.discordId, avatar: mockUser.avatar },
      );
    });

    it('디스코드 정보 업데이트 실패 시 에러를 반환해야 합니다', async () => {
      mockUserRepository.update.mockRejectedValue(new Error('Update failed'));

      const result = await service.updateDiscordInfo(mockUser);

      expect(result).toEqual({
        ok: false,
        error: new Error('Update failed'),
      });
    });
  });
});
