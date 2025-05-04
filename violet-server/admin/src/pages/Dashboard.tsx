import React, { useEffect, useState } from 'react';
import { Grid, Paper, Typography, Box } from '@mui/material';
import { Line } from 'react-chartjs-2';
import {
    Chart as ChartJS,
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
} from 'chart.js';
import { getStats } from '../services/api';

ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend
);

interface Stats {
    totalUsers: number;
    totalComments: number;
    userGrowth: {
        labels: string[];
        data: number[];
    };
    commentGrowth: {
        labels: string[];
        data: number[];
    };
}

const Dashboard: React.FC = () => {
    const [stats, setStats] = useState<Stats | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const data = await getStats();
                setStats(data);
            } catch (error) {
                console.error('통계 데이터를 가져오는데 실패했습니다:', error);
            } finally {
                setLoading(false);
            }
        };

        fetchStats();
    }, []);

    if (loading) {
        return <Typography>로딩 중...</Typography>;
    }

    if (!stats) {
        return <Typography>데이터를 불러오는데 실패했습니다.</Typography>;
    }

    const userData = {
        labels: stats.userGrowth.labels,
        datasets: [
            {
                label: '신규 사용자',
                data: stats.userGrowth.data,
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1,
            },
        ],
    };

    const commentData = {
        labels: stats.commentGrowth.labels,
        datasets: [
            {
                label: '댓글 수',
                data: stats.commentGrowth.data,
                borderColor: 'rgb(255, 99, 132)',
                tension: 0.1,
            },
        ],
    };

    const options = {
        responsive: true,
        plugins: {
            legend: {
                position: 'top' as const,
            },
            title: {
                display: true,
                text: '통계',
            },
        },
    };

    return (
        <Box>
            <Grid container spacing={3}>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2, height: '100%' }}>
                        <Typography variant="h6" gutterBottom>
                            사용자 통계
                        </Typography>
                        <Line options={options} data={userData} />
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2, height: '100%' }}>
                        <Typography variant="h6" gutterBottom>
                            댓글 통계
                        </Typography>
                        <Line options={options} data={commentData} />
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            총 사용자 수
                        </Typography>
                        <Typography variant="h4">{stats.totalUsers.toLocaleString()}</Typography>
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            총 댓글 수
                        </Typography>
                        <Typography variant="h4">{stats.totalComments.toLocaleString()}</Typography>
                    </Paper>
                </Grid>
            </Grid>
        </Box>
    );
};

export default Dashboard; 