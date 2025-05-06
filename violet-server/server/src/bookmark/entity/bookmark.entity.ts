import { ApiProperty } from '@nestjs/swagger';
import { CoreEntity } from 'src/common/entities/core.entity';
import { User } from 'src/user/entity/user.entity';
import { Column, Entity, ManyToOne, JoinColumn } from 'typeorm';

@Entity()
export class Bookmark extends CoreEntity {
    @ApiProperty({
        description: 'User Id',
        required: true,
    })
    @ManyToOne(() => User, (user) => user.userAppId)
    @JoinColumn({ name: 'userAppId' })
    user: User;

    @Column()
    fileName: string;

    @Column()
    fileUrl: string;
} 