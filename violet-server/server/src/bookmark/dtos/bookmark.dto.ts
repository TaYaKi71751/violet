import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';

export class BookmarkResponseDto {
    @IsString()
    @ApiProperty({
        description: 'File Name',
        required: true,
    })
    fileName: string;

    @IsString()
    @ApiProperty({
        description: 'File URL',
        required: true,
    })
    fileUrl: string;

    @IsString()
    @ApiProperty({
        description: 'Created At',
        required: true,
    })
    createdAt: Date;
}

export class BookmarkListResponseDto {
    @ApiProperty({
        description: 'Bookmark Elements',
        type: [BookmarkResponseDto],
        required: true,
    })
    elements: BookmarkResponseDto[];
} 