import { Injectable, CanActivate, ExecutionContext, ForbiddenException, NotFoundException } from '@nestjs/common';
import { UserRole } from 'src/user/entity/user.entity';
import { CommentService } from '../comment.service';

@Injectable()
export class CommentOwnerGuard implements CanActivate {
    constructor(private readonly commentService: CommentService) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const user = request.user;
        const commentId = parseInt(request.params.id);

        // Admin은 항상 접근 가능
        if (user.role === UserRole.ADMIN) {
            return true;
        }

        // 댓글 작성자만 접근 가능
        const comment = await this.commentService.getCommentById(commentId);
        if (!comment) {
            throw new NotFoundException('Comment not found');
        }

        if (comment.user.userAppId !== user.userAppId) {
            throw new ForbiddenException('Only comment owner or admin can perform this action');
        }

        return true;
    }
} 