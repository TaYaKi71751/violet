import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
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

export class ViewGetRequestDto {
  @IsInt()
  @Type(() => Number)
  @Min(0)
  @ApiProperty({
    description: 'Offset',
    required: true,
    type: 'integer',
  })
  offset: number;

  @IsInt()
  @Type(() => Number)
  @Min(0)
  @Max(1000)
  @ApiProperty({
    description: 'Count',
    required: true,
    type: 'integer',
  })
  count: number;

  @IsString()
  @IsOptional()
  @Matches(`^${Object.values(RANK_REQUEST_TYPE).join('|')}$`, 'i')
  @ApiProperty({ description: 'Type', required: false })
  type?: string = 'alltime';
}

export class ViewGetResponseDtoElement {
  @IsInt()
  @ApiProperty({
    description: 'Article Id',
    required: true,
    type: 'integer',
  })
  articleId: number;

  @IsInt()
  @ApiProperty({
    description: 'Count',
    required: true,
    type: 'integer',
  })
  count: number;
}

export class ViewGetResponseDto {
  @IsArray()
  @ApiProperty({
    description: 'View Get Elements',
    required: true,
    type: ViewGetResponseDtoElement,
    isArray: true,
  })
  elements: ViewGetResponseDtoElement[];
}
