import React from 'react';
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

ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend
);

const Dashboard: React.FC = () => {
    const userData = {
        labels: ['1월', '2월', '3월', '4월', '5월', '6월'],
        datasets: [
            {
                label: '신규 사용자',
                data: [65, 59, 80, 81, 56, 55],
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1,
            },
        ],
    };

    const commentData = {
        labels: ['1월', '2월', '3월', '4월', '5월', '6월'],
        datasets: [
            {
                label: '댓글 수',
                data: [12, 19, 3, 5, 2, 3],
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
                <Grid component="div" sx={{ width: { xs: '100%', md: '33.33%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            총 사용자 수
                        </Typography>
                        <Typography variant="h4">1,234</Typography>
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '33.33%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            총 댓글 수
                        </Typography>
                        <Typography variant="h4">5,678</Typography>
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '33.33%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            활성 사용자
                        </Typography>
                        <Typography variant="h4">890</Typography>
                    </Paper>
                </Grid>
            </Grid>
        </Box>
    );
};

export default Dashboard; 