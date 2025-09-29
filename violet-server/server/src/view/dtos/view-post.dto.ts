import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

export const RANK_REQUEST_TYPE = {
  DAILY: 'daily',
  WEEKLY: 'weekly',
  MONTHLY: 'monthly',
  ALLTIME: 'alltime',
};

export class ViewPostRequestDto {
  @IsInt()
  @Type(() => Number)
  @ApiProperty({
    description: 'ArticleId',
    required: true,
    type: 'integer',
  })
  articleId: number;

  @IsInt()
  @Type(() => Number)
  @Min(0)
  @Max(1000)
  @ApiProperty({
    description: 'Count',
    required: true,
    type: 'integer',
  })
  viewSeconds: number;

  @IsString()
  @ApiProperty({
    description: 'User App Id',
    required: true,
  })
  userAppId: string;
}
