import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client, Events, GatewayIntentBits, REST, Routes } from 'discord.js';
import { ViewService } from '../view/view.service';

@Injectable()
export class BotService implements OnModuleInit, OnModuleDestroy {
    private readonly logger = new Logger(BotService.name);
    private client: Client | null = null;

    constructor(
        private readonly configService: ConfigService,
        private readonly viewService: ViewService,
    ) { }

    async onModuleInit(): Promise<void> {
        const token = this.configService.get<string>('DISCORD_BOT_TOKEN');

        if (!token) {
            this.logger.warn('DISCORD_BOT_TOKEN 미설정 - Discord Bot 비활성화');
            return;
        }

        const applicationId = this.configService.get<string>('DISCORD_CLIENT_ID');
        if (!applicationId) {
            this.logger.warn('DISCORD_CLIENT_ID 미설정 - Slash Command 등록 불가');
            return;
        }

        this.client = new Client({
            intents: [
                GatewayIntentBits.Guilds,
            ],
        });

        this.client.once(Events.ClientReady, async (c) => {
            this.logger.log(`Discord Bot 로그인 완료: ${c.user.tag}`);
            await this.registerSlashCommands(token, applicationId);
        });

        this.client.on(Events.InteractionCreate, async (interaction) => {
            if (!interaction.isChatInputCommand()) return;
            if (interaction.commandName === 'ping') {
                try {
                    await interaction.reply('pong');
                } catch (error) {
                    this.logger.error('슬래시 커맨드 응답 실패', error as Error);
                }
            }
            if (interaction.commandName === 'top') {
                try {
                    const result = await this.viewService.getView({ offset: 0, count: 10, type: 'daily' });
                    if (!result.elements || result.elements.length === 0) {
                        await interaction.reply('결과가 없습니다.');
                        return;
                    }
                    const lines = result.elements.map((e, idx) => `${idx + 1}. articleId=${e.articleId}, count=${e.count}`);
                    const content = `Top 10 (daily)\n${lines.join('\n')}`;
                    await interaction.reply(content.substring(0, 1990));
                } catch (error) {
                    this.logger.error('슬래시 커맨드(top) 처리 실패', error as Error);
                    try { await interaction.reply('top 처리 중 오류가 발생했습니다.'); } catch { }
                }
            }
        });

        try {
            await this.client.login(token);
        } catch (error) {
            this.logger.error('봇 로그인 실패', error as Error);
        }
    }

    private async registerSlashCommands(token: string, applicationId: string): Promise<void> {
        const rest = new REST({ version: '10' }).setToken(token);
        const commands = [
            {
                name: 'ping',
                description: 'Replies with pong',
            },
            {
                name: 'top',
                description: 'Show top 10 daily views',
            },
        ];

        const guildId = this.configService.get<string>('DISCORD_GUILD_ID');
        const route = guildId
            ? Routes.applicationGuildCommands(applicationId, guildId)
            : Routes.applicationCommands(applicationId);

        try {
            await rest.put(route, { body: commands });
            if (guildId) {
                this.logger.log(`Slash Commands 등록 완료 (Guild: ${guildId})`);
            } else {
                this.logger.log('Slash Commands 등록 완료 (Global - 전파까지 최대 1시간 소요)');
            }
        } catch (error) {
            this.logger.error('Slash Commands 등록 실패', error as Error);
        }
    }

    async onModuleDestroy(): Promise<void> {
        if (this.client) {
            try {
                await this.client.destroy();
            } catch (error) {
                this.logger.error('봇 종료 중 오류', error as Error);
            } finally {
                this.client = null;
            }
        }
    }
}


