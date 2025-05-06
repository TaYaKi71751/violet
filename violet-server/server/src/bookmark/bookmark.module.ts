import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Bookmark } from './entity/bookmark.entity';
import { BookmarkService } from './bookmark.service';
import { BookmarkController } from './bookmark.controller';
import { BookmarkRepository } from './bookmark.repository';
import { AWSModule } from 'src/aws/aws.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Bookmark]),
        AWSModule,
    ],
    providers: [BookmarkRepository, BookmarkService],
    controllers: [BookmarkController],
})
export class BookmarkModule { }