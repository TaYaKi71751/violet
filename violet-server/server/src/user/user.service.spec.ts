import { Test, TestingModule } from '@nestjs/testing';
import { UserService } from './user.service';
import { UserRepository } from './user.repository';
import { UnauthorizedException } from '@nestjs/common';
import { UserRegisterDTO } from './dtos/user-register.dto';

describe('UserService', () => {
  let service: UserService;
  let repository: UserRepository;

  const mockUserRepository = {
    isUserExists: jest.fn(),
    createUser: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: UserRepository,
          useValue: mockUserRepository,
        },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
    repository = module.get<UserRepository>(UserRepository);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('registerUser', () => {
    const mockUserRegisterDTO: UserRegisterDTO = {
      userAppId: 'test-user-id',
    };

    it('유저 등록에 성공해야 합니다', async () => {
      // Arrange
      mockUserRepository.isUserExists.mockResolvedValue(false);
      mockUserRepository.createUser.mockResolvedValue(undefined);

      // Act
      const result = await service.registerUser(mockUserRegisterDTO);

      // Assert
      expect(result.ok).toBe(true);
      expect(mockUserRepository.isUserExists).toHaveBeenCalledWith(mockUserRegisterDTO.userAppId);
      expect(mockUserRepository.createUser).toHaveBeenCalledWith(mockUserRegisterDTO);
    });

    it('이미 존재하는 userAppId인 경우 UnauthorizedException을 발생시켜야 합니다', async () => {
      // Arrange
      mockUserRepository.isUserExists.mockResolvedValue(true);

      // Act
      const result = await service.registerUser(mockUserRegisterDTO);

      // Assert
      expect(result.ok).toBe(false);
      expect(result.error).toBeInstanceOf(UnauthorizedException);
      expect(mockUserRepository.createUser).toHaveBeenCalledTimes(1);
    });

    it('예외가 발생한 경우 에러를 포함한 실패 응답을 반환해야 합니다', async () => {
      // Arrange
      const testError = new Error('테스트 에러');
      mockUserRepository.isUserExists.mockRejectedValue(testError);

      // Act
      const result = await service.registerUser(mockUserRegisterDTO);

      // Assert
      expect(result.ok).toBe(false);
      expect(result.error).toBe(testError);
    });
  });
});
