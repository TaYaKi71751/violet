import { Module } from '@nestjs/common';
import { BotService } from './bot.service';
import { ViewModule } from '../view/view.module';

@Module({
    imports: [ViewModule],
    providers: [BotService],
})
export class BotModule { }


