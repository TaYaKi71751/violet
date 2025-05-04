import React, { useEffect, useState } from 'react';
import { getComments, deleteComment, updateComment, updateCommentStatus } from '../services/api';
import { Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Typography, IconButton, Select, MenuItem, FormControl, Box } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import EditIcon from '@mui/icons-material/Edit';

interface Comment {
    id: number;
    userAppId: string;
    body: string;
    dateTime: string;
    parent?: number;
    where: string;
    status: string;
}

const Comments: React.FC = () => {
    const [comments, setComments] = useState<Comment[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchComments = async () => {
            try {
                const data = await getComments();
                setComments(data.elements);
                setLoading(false);
            } catch (err) {
                setError('댓글 목록을 불러오는데 실패했습니다.');
                setLoading(false);
            }
        };

        fetchComments();
    }, []);

    const handleDelete = async (commentId: number) => {
        if (window.confirm('정말로 이 댓글을 삭제하시겠습니까?')) {
            try {
                await deleteComment(commentId);
                setComments(comments.filter(comment => comment.id !== commentId));
            } catch (err) {
                setError('댓글 삭제에 실패했습니다.');
            }
        }
    };

    const handleUpdate = async (commentId: number, newBody: string) => {
        try {
            await updateComment(commentId, { body: newBody });
            setComments(comments.map(comment =>
                comment.id === commentId ? { ...comment, body: newBody } : comment
            ));
        } catch (err) {
            setError('댓글 수정에 실패했습니다.');
        }
    };

    const handleStatusChange = async (commentId: number, newStatus: string) => {
        try {
            await updateCommentStatus(commentId, newStatus);
            setComments(comments.map(comment =>
                comment.id === commentId ? { ...comment, status: newStatus } : comment
            ));
        } catch (err) {
            setError('댓글 상태 변경에 실패했습니다.');
        }
    };

    if (loading) return <Typography>로딩 중...</Typography>;
    if (error) return <Typography color="error">{error}</Typography>;

    return (
        <Box sx={{ p: 3 }}>
            <Typography variant="h4" gutterBottom>
                댓글 관리
            </Typography>
            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>ID</TableCell>
                            <TableCell>작성자</TableCell>
                            <TableCell>내용</TableCell>
                            <TableCell>작성일</TableCell>
                            <TableCell>위치</TableCell>
                            <TableCell>부모 댓글</TableCell>
                            <TableCell>상태</TableCell>
                            <TableCell>관리</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {comments.map((comment) => (
                            <TableRow key={comment.id}>
                                <TableCell>{comment.id}</TableCell>
                                <TableCell>{comment.userAppId}</TableCell>
                                <TableCell>{comment.body}</TableCell>
                                <TableCell>{new Date(comment.dateTime).toLocaleString()}</TableCell>
                                <TableCell>{comment.where}</TableCell>
                                <TableCell>{comment.parent || '-'}</TableCell>
                                <TableCell>
                                    <FormControl size="small">
                                        <Select
                                            value={comment.status || 'active'}
                                            onChange={(e) => handleStatusChange(comment.id, e.target.value)}
                                        >
                                            <MenuItem value="active">활성</MenuItem>
                                            <MenuItem value="hidden">숨김</MenuItem>
                                            <MenuItem value="deleted">삭제됨</MenuItem>
                                        </Select>
                                    </FormControl>
                                </TableCell>
                                <TableCell>
                                    <IconButton onClick={() => handleDelete(comment.id)} color="error">
                                        <DeleteIcon />
                                    </IconButton>
                                    <IconButton onClick={() => {
                                        const newBody = prompt('수정할 내용을 입력하세요:', comment.body);
                                        if (newBody) handleUpdate(comment.id, newBody);
                                    }}>
                                        <EditIcon />
                                    </IconButton>
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>
        </Box>
    );
};

export default Comments; 