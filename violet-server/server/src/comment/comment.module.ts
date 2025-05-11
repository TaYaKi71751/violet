import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Comment } from 'src/comment/entity/comment.entity';
import { CommentService } from './comment.service';
import { CommentController } from './comment.controller';
import { CommentRepository } from './comment.repository';
import { DiscordModule } from '../discord/discord.module';
import { CommentOwnerGuard } from './guards/comment-owner.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([Comment]),
    DiscordModule,
  ],
  providers: [CommentRepository, CommentService, CommentOwnerGuard],
  controllers: [CommentController],
})
export class CommentModule { }
