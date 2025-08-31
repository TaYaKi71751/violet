import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { Comment } from 'src/comment/entity/comment.entity';
import {
  IsArray,
  IsDate,
  IsInt,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';
import { ValidateResponse } from 'src/common/decorators/validate-response.decorator';

export class CommentGetDto {
  @IsString()
  @ApiProperty({
    description: 'Where to get',
    required: true,
  })
  @Type(() => String)
  @Matches(`^(general|\d+)$`, 'i')
  where: string;
}

export class CommentGetResponseDtoElement {
  @IsInt()
  @ApiProperty({
    description: 'Comment Id',
    required: true,
    type: 'integer',
  })
  id: number;

  @IsString()
  @ApiProperty({
    description: 'Body',
    required: true,
  })
  @Matches(/^\w{8}$/, {
    message:
      'Id must be between 4 and 20 characters long with number or alphabet',
  })
  userAppId: string;

  @IsString()
  @ApiProperty({
    description: 'Body',
    required: true,
  })
  body: string;

  @IsDate()
  @ApiProperty({
    description: 'Write DateTime',
    required: true,
  })
  dateTime: Date;

  @IsString()
  @IsOptional()
  @ApiProperty({
    description: 'Parent Comment',
    required: false,
    type: 'integer',
  })
  parent?: number;

  @ValidateResponse(CommentGetResponseDtoElement)
  static from(comment: Comment): CommentGetResponseDtoElement {
    return {
      id: comment.id,
      userAppId: comment.user.userAppId.slice(0, 8),
      body: comment.body,
      dateTime: comment.createdAt,
      parent: comment.parent?.id,
    };
  }
}

export class CommentGetResponseDto {
  @IsArray()
  @ApiProperty({
    description: 'Comment Elements',
    required: true,
    type: CommentGetResponseDtoElement,
    isArray: true,
  })
  elements: CommentGetResponseDtoElement[];
}
