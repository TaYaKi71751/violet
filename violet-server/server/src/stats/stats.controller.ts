import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { StatsService } from './stats.service';
import { StatsResponseDto } from './dtos/stats.dto';
import { AccessTokenGuard } from '../auth/guards/access-token.guard';

@ApiTags('stats')
@Controller('stats')
// @UseGuards(AccessTokenGuard)
export class StatsController {
    constructor(private readonly statsService: StatsService) { }

    @Get()
    @ApiOperation({ summary: '통계 데이터 조회' })
    @ApiResponse({
        status: 200,
        description: '통계 데이터',
        type: StatsResponseDto,
    })
    async getStats(): Promise<StatsResponseDto> {
        return this.statsService.getStats();
    }
} 