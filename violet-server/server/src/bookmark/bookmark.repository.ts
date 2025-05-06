import { Injectable } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { Bookmark } from './entity/bookmark.entity';
import { User } from 'src/user/entity/user.entity';

@Injectable()
export class BookmarkRepository extends Repository<Bookmark> {
    constructor(private dataSource: DataSource) {
        super(Bookmark, dataSource.createEntityManager());
    }

    async createBookmark(user: User, fileName: string, fileUrl: string): Promise<Bookmark> {
        const bookmark = this.create({
            user,
            fileName,
            fileUrl,
        });

        try {
            await this.save(bookmark);
            return bookmark;
        } catch (error) {
            throw new Error(error);
        }
    }

    async getUserBookmarks(userAppId: string): Promise<Bookmark[]> {
        return await this.find({
            where: {
                user: { userAppId },
            },
            order: {
                createdAt: 'DESC',
            },
        });
    }
} 