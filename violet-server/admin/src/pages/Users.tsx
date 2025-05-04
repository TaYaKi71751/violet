import React from 'react';
import { Box, Paper, Typography } from '@mui/material';
import { DataGrid, GridColDef } from '@mui/x-data-grid';

const columns: GridColDef[] = [
    { field: 'id', headerName: 'ID', width: 90 },
    { field: 'username', headerName: '사용자명', width: 150 },
    { field: 'email', headerName: '이메일', width: 200 },
    { field: 'role', headerName: '역할', width: 130 },
    { field: 'status', headerName: '상태', width: 130 },
    { field: 'createdAt', headerName: '가입일', width: 180 },
];

const rows = [
    { id: 1, username: 'user1', email: 'user1@example.com', role: '일반', status: '활성', createdAt: '2024-01-01' },
    { id: 2, username: 'user2', email: 'user2@example.com', role: '관리자', status: '활성', createdAt: '2024-01-02' },
    { id: 3, username: 'user3', email: 'user3@example.com', role: '일반', status: '비활성', createdAt: '2024-01-03' },
];

const Users: React.FC = () => {
    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                사용자 관리
            </Typography>
            <Paper sx={{ height: 400, width: '100%' }}>
                <DataGrid
                    rows={rows}
                    columns={columns}
                    initialState={{
                        pagination: {
                            paginationModel: { page: 0, pageSize: 5 },
                        },
                    }}
                    pageSizeOptions={[5, 10]}
                    checkboxSelection
                />
            </Paper>
        </Box>
    );
};

export default Users; 