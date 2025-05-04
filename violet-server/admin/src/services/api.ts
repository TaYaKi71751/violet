import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

export const getUsers = async () => {
    const response = await api.get('/users');
    return response.data;
};

export const getComments = async () => {
    const response = await api.get('/comments');
    return response.data;
};

export const getStats = async () => {
    const response = await api.get('/stats');
    return response.data;
};

export const updateUserStatus = async (userId: number, status: string) => {
    const response = await api.patch(`/users/${userId}/status`, { status });
    return response.data;
};

export const updateCommentStatus = async (commentId: number, status: string) => {
    const response = await api.patch(`/comments/${commentId}/status`, { status });
    return response.data;
};

export const updateSettings = async (settings: any) => {
    const response = await api.put('/settings', settings);
    return response.data;
};

export default api; 