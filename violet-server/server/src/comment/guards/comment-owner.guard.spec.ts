import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, ForbiddenException, NotFoundException } from '@nestjs/common';
import { CommentOwnerGuard } from './comment-owner.guard';
import { CommentService } from '../comment.service';
import { User, UserRole } from 'src/user/entity/user.entity';
import { Comment } from '../entity/comment.entity';

describe('CommentOwnerGuard', () => {
    let guard: CommentOwnerGuard;
    let commentService: CommentService;

    const mockCommentService = {
        getCommentById: jest.fn(),
    };

    const mockExecutionContext = {
        switchToHttp: () => ({
            getRequest: () => ({
                user: {
                    userAppId: 'test-user-id',
                    role: UserRole.USER,
                },
                params: {
                    id: '1',
                },
            }),
        }),
    } as ExecutionContext;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                CommentOwnerGuard,
                {
                    provide: CommentService,
                    useValue: mockCommentService,
                },
            ],
        }).compile();

        guard = module.get<CommentOwnerGuard>(CommentOwnerGuard);
        commentService = module.get<CommentService>(CommentService);
    });

    it('should be defined', () => {
        expect(guard).toBeDefined();
    });

    describe('canActivate', () => {
        it('should allow admin users to access any comment', async () => {
            const adminContext = {
                switchToHttp: () => ({
                    getRequest: () => ({
                        user: {
                            userAppId: 'admin-id',
                            role: UserRole.ADMIN,
                        },
                        params: {
                            id: '1',
                        },
                    }),
                }),
            } as ExecutionContext;

            const result = await guard.canActivate(adminContext);
            expect(result).toBe(true);
            expect(mockCommentService.getCommentById).not.toHaveBeenCalled();
        });

        it('should allow comment owner to access their own comment', async () => {
            const mockComment = {
                id: 1,
                user: {
                    userAppId: 'test-user-id',
                },
            } as Comment;

            mockCommentService.getCommentById.mockResolvedValue(mockComment);

            const result = await guard.canActivate(mockExecutionContext);
            expect(result).toBe(true);
            expect(mockCommentService.getCommentById).toHaveBeenCalledWith(1);
        });

        it('should throw ForbiddenException when non-owner tries to access comment', async () => {
            const mockComment = {
                id: 1,
                user: {
                    userAppId: 'different-user-id',
                },
            } as Comment;

            mockCommentService.getCommentById.mockResolvedValue(mockComment);

            await expect(guard.canActivate(mockExecutionContext)).rejects.toThrow(
                ForbiddenException,
            );
            expect(mockCommentService.getCommentById).toHaveBeenCalledWith(1);
        });

        it('should throw NotFoundException when comment is not found', async () => {
            mockCommentService.getCommentById.mockResolvedValue(null);

            await expect(guard.canActivate(mockExecutionContext)).rejects.toThrow(
                NotFoundException,
            );
            expect(mockCommentService.getCommentById).toHaveBeenCalledWith(1);
        });
    });
}); 