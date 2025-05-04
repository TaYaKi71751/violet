import React from 'react';
import { Box, Paper, Typography } from '@mui/material';
import { DataGrid, GridColDef } from '@mui/x-data-grid';

const columns: GridColDef[] = [
    { field: 'id', headerName: 'ID', width: 90 },
    { field: 'content', headerName: '내용', width: 300 },
    { field: 'author', headerName: '작성자', width: 150 },
    { field: 'postId', headerName: '게시글 ID', width: 100 },
    { field: 'status', headerName: '상태', width: 130 },
    { field: 'createdAt', headerName: '작성일', width: 180 },
    { field: 'reports', headerName: '신고 수', width: 100 },
];

const rows = [
    { id: 1, content: '첫 번째 댓글입니다.', author: 'user1', postId: 1, status: '정상', createdAt: '2024-01-01', reports: 0 },
    { id: 2, content: '두 번째 댓글입니다.', author: 'user2', postId: 1, status: '신고', createdAt: '2024-01-02', reports: 3 },
    { id: 3, content: '세 번째 댓글입니다.', author: 'user3', postId: 2, status: '삭제', createdAt: '2024-01-03', reports: 5 },
];

const Comments: React.FC = () => {
    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                댓글 관리
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

export default Comments; 