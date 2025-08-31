import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export class CommentPostDto {
  @IsString()
  @ApiProperty({
    description: 'Where to post',
    required: true,
  })
  @Type(() => String)
  @Matches(`^(general|\d+)$`, 'i')
  @MaxLength(20)
  where: string;

  @IsString()
  @ApiProperty({
    description: 'Post Body',
    required: true,
  })
  @Type(() => String)
  @MaxLength(500)
  body: string;

  @IsInt()
  @IsOptional()
  @ApiProperty({
    description: 'Parent Comment',
    required: false,
    type: 'integer',
  })
  @Type(() => Number)
  parent?: number;
}
