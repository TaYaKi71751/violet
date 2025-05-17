import React, { useEffect, useState } from 'react';
import { getUsers, updateUserStatus, deleteUser } from '../services/api';
import { Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Typography, IconButton, Select, MenuItem, FormControl } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';

interface User {
    userAppId: string;
    createdAt: string;
    updatedAt: string;
    status: string;
}

const UserManagement: React.FC = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                const data = await getUsers();
                setUsers(data);
                setLoading(false);
            } catch (err) {
                setError('사용자 목록을 불러오는데 실패했습니다.');
                setLoading(false);
            }
        };

        fetchUsers();
    }, []);

    const handleStatusChange = async (userAppId: string, newStatus: string) => {
        try {
            await updateUserStatus(userAppId, newStatus);
            setUsers(users.map(user =>
                user.userAppId === userAppId ? { ...user, status: newStatus } : user
            ));
        } catch (err) {
            setError('사용자 상태 변경에 실패했습니다.');
        }
    };

    const handleDelete = async (userAppId: string) => {
        if (window.confirm('정말로 이 사용자를 삭제하시겠습니까?')) {
            try {
                await deleteUser(userAppId);
                setUsers(users.filter(user => user.userAppId !== userAppId));
            } catch (err) {
                setError('사용자 삭제에 실패했습니다.');
            }
        }
    };

    if (loading) return <Typography>로딩 중...</Typography>;
    if (error) return <Typography color="error">{error}</Typography>;

    return (
        <TableContainer component={Paper}>
            <Table>
                <TableHead>
                    <TableRow>
                        <TableCell>사용자 ID</TableCell>
                        <TableCell>상태</TableCell>
                        <TableCell>가입일</TableCell>
                        <TableCell>마지막 수정일</TableCell>
                        <TableCell>관리</TableCell>
                    </TableRow>
                </TableHead>
                <TableBody>
                    {users.map((user) => (
                        <TableRow key={user.userAppId}>
                            <TableCell>{user.userAppId}</TableCell>
                            <TableCell>
                                <FormControl size="small">
                                    <Select
                                        value={user.status || 'active'}
                                        onChange={(e) => handleStatusChange(user.userAppId, e.target.value)}
                                    >
                                        <MenuItem value="active">활성</MenuItem>
                                        <MenuItem value="inactive">비활성</MenuItem>
                                        <MenuItem value="banned">차단</MenuItem>
                                    </Select>
                                </FormControl>
                            </TableCell>
                            <TableCell>{new Date(user.createdAt).toLocaleString()}</TableCell>
                            <TableCell>{new Date(user.updatedAt).toLocaleString()}</TableCell>
                            <TableCell>
                                <IconButton onClick={() => handleDelete(user.userAppId)} color="error">
                                    <DeleteIcon />
                                </IconButton>
                            </TableCell>
                        </TableRow>
                    ))}
                </TableBody>
            </Table>
        </TableContainer>
    );
};

export default UserManagement; 