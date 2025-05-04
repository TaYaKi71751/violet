import React from 'react';
import { Box, Paper, Typography, Grid, TextField, Button, Switch, FormControlLabel } from '@mui/material';

const Settings: React.FC = () => {
    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                시스템 설정
            </Typography>
            <Grid container spacing={3}>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            시스템 설정
                        </Typography>
                        <TextField
                            fullWidth
                            label="시스템 이름"
                            variant="outlined"
                            margin="normal"
                        />
                        <TextField
                            fullWidth
                            label="관리자 이메일"
                            variant="outlined"
                            margin="normal"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }}>
                            저장
                        </Button>
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '50%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            알림 설정
                        </Typography>
                        <TextField
                            fullWidth
                            label="알림 이메일"
                            variant="outlined"
                            margin="normal"
                        />
                        <TextField
                            fullWidth
                            label="알림 주기 (분)"
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }}>
                            저장
                        </Button>
                    </Paper>
                </Grid>
                <Grid component="div" sx={{ width: { xs: '100%', md: '100%' } }}>
                    <Paper sx={{ p: 2 }}>
                        <Typography variant="h6" gutterBottom>
                            보안 설정
                        </Typography>
                        <TextField
                            fullWidth
                            label="세션 타임아웃 (분)"
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <TextField
                            fullWidth
                            label="최대 로그인 시도 횟수"
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }}>
                            저장
                        </Button>
                    </Paper>
                </Grid>
            </Grid>
        </Box>
    );
};

export default Settings; 