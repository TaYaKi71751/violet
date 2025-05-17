import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { CommentPostDto } from 'src/comment/dtos/comment-post.dto';

@Injectable()
export class DiscordService {
    private webhookUrl: string;

    constructor(private readonly configService: ConfigService) {
        this.webhookUrl = this.configService.get<string>('DISCORD_WEBHOOK_URL');
    }

    async sendCommentNotification(username: string, dto: CommentPostDto) {
        if (!this.webhookUrl) {
            Logger.error('Discord webhook URL not configured');
            return;
        }

        try {
            await axios.post(this.webhookUrl, {
                embeds: [{
                    title: `Channel: ${dto.where}`,
                    description: dto.body,
                    color: 0x00ff00,
                    fields: [
                        {
                            name: 'Author',
                            value: username,
                        }
                    ],
                    timestamp: new Date().toISOString(),
                }]
            });
        } catch (error) {
            Logger.error('Failed to send Discord webhook:', error);
        }
    }
} 