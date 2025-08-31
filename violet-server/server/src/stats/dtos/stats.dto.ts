import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsArray } from 'class-validator';

export class StatsResponseDto {
    @IsInt()
    @ApiProperty({
        description: '총 사용자 수',
        required: true,
        type: 'integer',
    })
    totalUsers: number;

    @IsInt()
    @ApiProperty({
        description: '총 댓글 수',
        required: true,
        type: 'integer',
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