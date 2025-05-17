import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000/api/v2';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
    withCredentials: true,
});

// 인증 관련 API
export const login = async (userAppId: string) => {
    const response = await api.post('/auth/login', { userAppId });
    return response.data;
};

// 사용자 관리 API
export const getUsers = async () => {
    const response = await api.get('/user/list');
    return response.data;
};

export const updateUserStatus = async (userAppId: string, status: string) => {
    const response = await api.patch(`/user/${userAppId}/status`, { status });
    return response.data;
};

export const deleteUser = async (userAppId: string) => {
    const response = await api.delete(`/user/${userAppId}`);
    return response.data;
};

// 댓글 관리 API
export const getComments = async () => {
    const response = await api.get('/comment?where=general');
    return response.data;
};

export const deleteComment = async (commentId: number) => {
    const response = await api.delete(`/comment/${commentId}`);
    return response.data;
};

export const updateComment = async (commentId: number, data: { body: string }) => {
    const response = await api.patch(`/comment/${commentId}`, data);
    return response.data;
};

export const updateCommentStatus = async (commentId: number, status: string) => {
    const response = await api.patch(`/comment/${commentId}/status`, { status });
    return response.data;
};

export const getStats = async () => {
    const response = await api.get('/stats');
    return response.data;
};

export const getSettings = async () => {
    const response = await api.get('/settings');
    return response.data;
};

export const updateSettings = async (settings: any) => {
    const response = await api.put('/settings', settings);
    return response.data;
};

export default api; 