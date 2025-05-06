import {
    Controller,
    Get,
    Post,
    UseGuards,
    UsePipes,
    ValidationPipe,
} from '@nestjs/common';
import { BookmarkService } from './bookmark.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { User } from 'src/user/entity/user.entity';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';
import { BookmarkListResponseDto } from './dtos/bookmark.dto';
import { CommonResponseDto } from 'src/common/dtos/common.dto';

@ApiTags('bookmark')
@Controller('bookmark')
export class BookmarkController {
    constructor(private readonly bookmarkService: BookmarkService) { }

    @Post('/backup')
    @UsePipes(new ValidationPipe({ transform: true }))
    @ApiOperation({ summary: 'Create Bookmark Backup' })
    @UseGuards(HmacAuthGuard)
    @UseGuards(AccessTokenGuard)
    async createBookmarkBackup(
        @CurrentUser() currentUser: User,
    ): Promise<CommonResponseDto> {
        return await this.bookmarkService.createBookmarkBackup(currentUser);
    }

    @Get('/')
    @UsePipes(new ValidationPipe({ transform: true }))
    @ApiOperation({ summary: 'Get User Bookmarks' })
    @UseGuards(HmacAuthGuard)
    @UseGuards(AccessTokenGuard)
    async getUserBookmarks(
        @CurrentUser() currentUser: User,
    ): Promise<BookmarkListResponseDto> {
        return await this.bookmarkService.getUserBookmarks(currentUser);
    }
} 