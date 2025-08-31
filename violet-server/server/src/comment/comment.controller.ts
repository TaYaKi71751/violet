import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
  Param,
  Patch,
} from '@nestjs/common';
import { CommentService } from './comment.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CommentPostDto } from './dtos/comment-post.dto';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { User } from 'src/user/entity/user.entity';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';
import { CommentGetDto, CommentGetResponseDto } from './dtos/comment-get.dto';
import { CommonResponseDto } from 'src/common/dtos/common.dto';
import { CommentOwnerGuard } from './guards/comment-owner.guard';

@ApiTags('comment')
@Controller('comment')
export class CommentController {
  constructor(private readonly commentService: CommentService) { }

  @Get('/')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiCreatedResponse({
    description: 'Comment Elements',
    type: CommentGetResponseDto,
  })
  @ApiOperation({ summary: 'Get Comment' })
  @UseGuards(HmacAuthGuard)
  async getComment(@Query() dto: CommentGetDto): Promise<CommentGetResponseDto> {
    return await this.commentService.getComment(dto);
  }

  @Post('/')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post Comment' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async postComment(
    @CurrentUser() currentUser: User,
    @Body() dto: CommentPostDto,
  ): Promise<CommonResponseDto> {
    return await this.commentService.postComment(currentUser, dto);
  }

  @Patch('/:id/hidden')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Toggle comment hidden status' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  @UseGuards(CommentOwnerGuard)
  async toggleCommentHidden(
    @Param('id') id: number,
    @Body('isHidden') isHidden: boolean,
  ): Promise<CommonResponseDto> {
    return await this.commentService.toggleCommentHidden(id, isHidden);
  }
}
