import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StatsController } from './stats.controller';
import { StatsService } from './stats.service';
import { User } from '../user/entity/user.entity';
import { Comment } from '../comment/entity/comment.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([User, Comment]),
    ],
    controllers: [StatsController],
    providers: [StatsService],
})
export class StatsModule { } 