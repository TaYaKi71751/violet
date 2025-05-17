import { Injectable, Logger } from '@nestjs/common';
import { BookmarkRepository } from './bookmark.repository';
import { User } from 'src/user/entity/user.entity';
import { BookmarkListResponseDto, BookmarkResponseDto } from './dtos/bookmark.dto';
import { AWSService } from 'src/aws/aws.service';
import { CommonResponseDto } from 'src/common/dtos/common.dto';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class BookmarkService {
    constructor(
        private readonly bookmarkRepository: BookmarkRepository,
        private readonly awsService: AWSService,
        private readonly configService: ConfigService,
    ) { }

    async createBookmarkBackup(user: User): Promise<CommonResponseDto> {
        try {
            const fileName = `${user.userAppId}-${new Date().toISOString().split('T')[0]}.db`;
            const bucket = this.configService.get('BOOKMARK_BACKUP_BUCKET');
            const { url } = await this.awsService.makePresignedPost(bucket, fileName);

            await this.bookmarkRepository.createBookmark(
                user,
                fileName,
                url,
            );

            return { ok: true };
        } catch (e) {
            Logger.error(e);
            return { ok: false, error: e };
        }
    }

    async getUserBookmarks(user: User): Promise<BookmarkListResponseDto> {
        try {
            const bookmarks = await this.bookmarkRepository.getUserBookmarks(user.userAppId);
            return {
                elements: bookmarks.map(bookmark => ({
                    fileName: bookmark.fileName,
                    fileUrl: bookmark.fileUrl,
                    createdAt: bookmark.createdAt,
                })),
            };
        } catch (e) {
            Logger.error(e);
            throw e;
        }
    }
} 