import { Injectable, ExecutionContext, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from 'src/user/entity/user.entity';

@Injectable()
export class AdminGuard extends AuthGuard('jwt-access') {
    canActivate(context: ExecutionContext) {
        return super.canActivate(context);
    }

    handleRequest(err: any, user: any) {
        if (err || !user) {
            throw err || new UnauthorizedException('Retry login');
        }

        if (user && user.role && user.role === UserRole.ADMIN) {
            return user;
        }

        throw new ForbiddenException('Only admin can perform this action');
    }
} 