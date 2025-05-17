import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../user/entity/user.entity';
import { Comment } from '../comment/entity/comment.entity';
import { StatsResponseDto } from './dtos/stats.dto';

@Injectable()
export class StatsService {
    constructor(
        @InjectRepository(User)
        private readonly userRepository: Repository<User>,
        @InjectRepository(Comment)
        private readonly commentRepository: Repository<Comment>,
    ) { }

    async getStats(): Promise<StatsResponseDto> {
        const [totalUsers, totalComments] = await Promise.all([
            this.userRepository.count(),
            this.commentRepository.count(),
        ]);

        const userGrowth = await this.getUserGrowth();
        const commentGrowth = await this.getCommentGrowth();

        return {
            totalUsers,
            totalComments,
            userGrowth,
            commentGrowth,
        };
    }

    private async getUserGrowth(): Promise<{ labels: string[]; data: number[] }> {
        const last6Months = Array.from({ length: 6 }, (_, i) => {
            const date = new Date();
            date.setMonth(date.getMonth() - i);
            return date;
        }).reverse();

        const labels = last6Months.map(date =>
            `${date.getMonth() + 1}월`
        );

        const data = await Promise.all(
            last6Months.map(async (date) => {
                const startOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
                const endOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0);

                const count = await this.userRepository
                    .createQueryBuilder('user')
                    .where('user.createdAt BETWEEN :start AND :end', {
                        start: startOfMonth,
                        end: endOfMonth,
                    })
                    .getCount();

                return count;
            })
        );

        return { labels, data };
    }

    private async getCommentGrowth(): Promise<{ labels: string[]; data: number[] }> {
        const last6Months = Array.from({ length: 6 }, (_, i) => {
            const date = new Date();
            date.setMonth(date.getMonth() - i);
            return date;
        }).reverse();

        const labels = last6Months.map(date =>
            `${date.getMonth() + 1}월`
        );

        const data = await Promise.all(
            last6Months.map(async (date) => {
                const startOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
                const endOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0);

                const count = await this.commentRepository
                    .createQueryBuilder('comment')
                    .where('comment.createdAt BETWEEN :start AND :end', {
                        start: startOfMonth,
                        end: endOfMonth,
                    })
                    .getCount();

                return count;
            })
        );

        return { labels, data };
    }
} 