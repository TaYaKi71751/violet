import React, { useEffect, useState } from 'react';
import { Box, Paper, Typography, Grid, TextField, Button, Switch, FormControlLabel, Snackbar, Alert } from '@mui/material';
import { getSettings, updateSettings } from '../services/api';

interface Settings {
    systemName: string;
    adminEmail: string;
    notificationEmail: string;
    notificationInterval: number;
    sessionTimeout: number;
    maxLoginAttempts: number;
}

const Settings: React.FC = () => {
    const [settings, setSettings] = useState<Settings>({
        systemName: '',
        adminEmail: '',
        notificationEmail: '',
        notificationInterval: 60,
        sessionTimeout: 30,
        maxLoginAttempts: 5,
    });
    const [loading, setLoading] = useState(true);
    const [snackbar, setSnackbar] = useState({
        open: false,
        message: '',
        severity: 'success' as 'success' | 'error',
    });

    useEffect(() => {
        const fetchSettings = async () => {
            try {
                const data = await getSettings();
                setSettings(data);
            } catch (error) {
                console.error('설정을 가져오는데 실패했습니다:', error);
                setSnackbar({
                    open: true,
                    message: '설정을 가져오는데 실패했습니다.',
                    severity: 'error',
                });
            } finally {
                setLoading(false);
            }
        };

        fetchSettings();
    }, []);

    const handleChange = (field: keyof Settings) => (
        event: React.ChangeEvent<HTMLInputElement>
    ) => {
        setSettings({
            ...settings,
            [field]: field.includes('Interval') || field.includes('Timeout') || field.includes('Attempts')
                ? parseInt(event.target.value) || 0
                : event.target.value,
        });
    };

    const handleSave = async () => {
        try {
            await updateSettings(settings);
            setSnackbar({
                open: true,
                message: '설정이 성공적으로 저장되었습니다.',
                severity: 'success',
            });
        } catch (error) {
            console.error('설정 저장에 실패했습니다:', error);
            setSnackbar({
                open: true,
                message: '설정 저장에 실패했습니다.',
                severity: 'error',
            });
        }
    };

    if (loading) {
        return <Typography>로딩 중...</Typography>;
    }

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
                            value={settings.systemName}
                            onChange={handleChange('systemName')}
                            variant="outlined"
                            margin="normal"
                        />
                        <TextField
                            fullWidth
                            label="관리자 이메일"
                            value={settings.adminEmail}
                            onChange={handleChange('adminEmail')}
                            variant="outlined"
                            margin="normal"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }} onClick={handleSave}>
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
                            value={settings.notificationEmail}
                            onChange={handleChange('notificationEmail')}
                            variant="outlined"
                            margin="normal"
                        />
                        <TextField
                            fullWidth
                            label="알림 주기 (분)"
                            value={settings.notificationInterval}
                            onChange={handleChange('notificationInterval')}
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }} onClick={handleSave}>
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
                            value={settings.sessionTimeout}
                            onChange={handleChange('sessionTimeout')}
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <TextField
                            fullWidth
                            label="최대 로그인 시도 횟수"
                            value={settings.maxLoginAttempts}
                            onChange={handleChange('maxLoginAttempts')}
                            variant="outlined"
                            margin="normal"
                            type="number"
                        />
                        <Button variant="contained" color="primary" sx={{ mt: 2 }} onClick={handleSave}>
                            저장
                        </Button>
                    </Paper>
                </Grid>
            </Grid>
            <Snackbar
                open={snackbar.open}
                autoHideDuration={6000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
            >
                <Alert
                    onClose={() => setSnackbar({ ...snackbar, open: false })}
                    severity={snackbar.severity}
                    sx={{ width: '100%' }}
                >
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default Settings; 