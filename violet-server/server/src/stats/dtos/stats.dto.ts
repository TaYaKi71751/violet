import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsArray } from 'class-validator';

export class StatsResponseDto {
    @IsNumber()
    @ApiProperty({
        description: '총 사용자 수',
        required: true,
    })
    totalUsers: number;

    @IsNumber()
    @ApiProperty({
        description: '총 댓글 수',
        required: true,
    })
    totalComments: number;

    @ApiProperty({
        description: '사용자 성장 데이터',
        required: true,
    })
    userGrowth: {
        labels: string[];
        data: number[];
    };

    @ApiProperty({
        description: '댓글 성장 데이터',
        required: true,
    })
    commentGrowth: {
        labels: string[];
        data: number[];
    };
} 