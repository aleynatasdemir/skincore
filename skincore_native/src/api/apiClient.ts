import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import * as SecureStore from 'expo-secure-store';
import type {
  AuthResponse,
  MessageResponse,
  UserResponse,
} from '../types/auth';
import type {
  Product,
  ProductWithEnrichedIngredients,
  PopularProductResponse,
  SearchHistoryResponse,
  AddSearchHistoryRequest,
  FavoriteResponse,
  AddFavoriteRequest,
  ToggleFavoriteResponse,
  IsFavoriteResponse,
  MatchedIngredient,
} from '../types/product';
import type {
  RoutineFeedItem,
  RoutineDetail,
  ToggleLikeResponse,
  RoutineCommentResponse,
  CreateRoutineRequest,
  UserProfileResponse,
  PublicUserProfileResponse,
  UpdateProfileRequest,
  UpdateBioRequest,
} from '../types/social';

// MARK: - Sabitler

// Localhost üzerinden .NET backend'e bağlanıyoruz
export const API_BASE_URL = 'http://localhost:5192/api';
export const MEDIA_BASE_URL = 'http://localhost:5192';

const ACCESS_TOKEN_KEY = 'com.skincore.accessToken';
const REFRESH_TOKEN_KEY = 'com.skincore.refreshToken';

// MARK: - Token Yönetimi (expo-secure-store → Swift KeychainService karşılığı)

export const TokenStorage = {
  async getAccessToken(): Promise<string | null> {
    return SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
  },
  async getRefreshToken(): Promise<string | null> {
    return SecureStore.getItemAsync(REFRESH_TOKEN_KEY);
  },
  async saveTokens(response: AuthResponse): Promise<void> {
    await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.accessToken);
    await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, response.refreshToken);
  },
  async clearAll(): Promise<void> {
    await SecureStore.deleteItemAsync(ACCESS_TOKEN_KEY);
    await SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY);
  },
};

// MARK: - Görsel URL Çözücü

export function resolveMediaUrl(path: string | undefined | null): string | undefined {
  if (!path || path.trim() === '') return undefined;
  if (path.startsWith('http')) return path;
  return `${MEDIA_BASE_URL}${path}`;
}

// MARK: - Axios Instance

const api: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
});

// Request interceptor: access token ekle
api.interceptors.request.use(async (config: InternalAxiosRequestConfig) => {
  const token = await TokenStorage.getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: 401 → refresh token → retry
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (error: unknown) => void;
}> = [];

function processQueue(error: unknown, token: string | null) {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) reject(error);
    else if (token) resolve(token);
  });
  failedQueue = [];
}

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          return api(originalRequest);
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = await TokenStorage.getRefreshToken();
        if (!refreshToken) throw new Error('No refresh token');

        const response = await axios.post<AuthResponse>(
          `${API_BASE_URL}/auth/refresh`,
          { refreshToken }
        );
        await TokenStorage.saveTokens(response.data);
        const newToken = response.data.accessToken;
        processQueue(null, newToken);
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return api(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);
        await TokenStorage.clearAll();
        // Auth store'u trigger etmek için event emit edilebilir, şimdilik throw
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

// MARK: - Hata mesajı çıkarıcı

export function extractErrorMessage(error: unknown, fallback = 'Bir hata oluştu.'): string {
  console.error('[API Error]:', error);
  if (axios.isAxiosError(error)) {
    if (error.response?.data) {
      console.error('[API Error Data]:', error.response.data);
      if (error.response.data.message) {
        return error.response.data.message;
      }
      if (error.response.data.title) {
        return error.response.data.title;
      }
    }
    // Network Error veya timeout ise:
    return error.message ?? fallback;
  }
  if (error instanceof Error) return error.message;
  return fallback;
}

// MARK: - Auth Endpoints

export const authApi = {
  register: (body: { email: string; password: string; fullName?: string }) =>
    api.post<MessageResponse>('/auth/register', body).then((r) => r.data),

  verifyEmail: (body: { email: string; code: string }) =>
    api.post<AuthResponse>('/auth/verify-email', body).then((r) => r.data),

  login: (body: { email: string; password: string }) =>
    api.post<AuthResponse>('/auth/login', body).then((r) => r.data),

  appleSignIn: (body: { identityToken: string; fullName?: string; email?: string }) =>
    api.post<AuthResponse>('/auth/apple', body).then((r) => r.data),

  resendCode: (email: string) =>
    api.post<MessageResponse>('/auth/resend-code', { email }).then((r) => r.data),

  refreshToken: (refreshToken: string) =>
    api.post<AuthResponse>('/auth/refresh', { refreshToken }).then((r) => r.data),

  getMe: () => api.get<UserResponse>('/auth/me').then((r) => r.data),

  forgotPassword: (email: string) =>
    api.post<MessageResponse>('/auth/forgot-password', { email }).then((r) => r.data),

  resetPassword: (body: { email: string; code: string; newPassword: string }) =>
    api.post<MessageResponse>('/auth/reset-password', body).then((r) => r.data),

  changePassword: (body: { currentPassword: string; newPassword: string }) =>
    api.put<MessageResponse>('/auth/change-password', body).then((r) => r.data),

  updateNotifications: (enabled: boolean) =>
    api.put<MessageResponse>('/auth/notifications', { enabled }).then((r) => r.data),

  deleteAccount: () =>
    api.delete<MessageResponse>('/auth/account').then((r) => r.data),
};

// MARK: - Product Endpoints

export const productsApi = {
  searchByName: (query: string, maxResults = 5) =>
    api
      .get<Product[]>('/products/search/name', { params: { query, maxResults } })
      .then((r) => r.data),

  getDetails: (id: string) =>
    api.get<ProductWithEnrichedIngredients>(`/products/${id}`).then((r) => r.data),

  searchByImage: async (
    imageData: FormData
  ): Promise<Product[]> => {
    const response = await api.post<Product[]>('/products/search/image', imageData);
    return response.data;
  },

  submitRequest: async (formData: FormData): Promise<MessageResponse> => {
    const response = await api.post<MessageResponse>('/product-requests', formData);
    return response.data;
  },
};

// MARK: - Moderation Endpoints

export const moderationApi = {
  submitRequest: async (productId: string, formData: FormData): Promise<MessageResponse> => {
    const response = await api.post<MessageResponse>(
      `/moderation/products/${productId}`,
      formData
    );
    return response.data;
  },
};

// MARK: - Popular Endpoints

export const popularApi = {
  get: (limit = 10) =>
    api.get<PopularProductResponse[]>('/popular', { params: { limit } }).then((r) => r.data),
};

// MARK: - Search History Endpoints

export const searchHistoryApi = {
  get: (limit = 20) =>
    api
      .get<SearchHistoryResponse[]>('/userprofile/search-history', { params: { limit } })
      .then((r) => r.data),

  add: (body: AddSearchHistoryRequest) =>
    api
      .post<MessageResponse>('/userprofile/search-history', body)
      .then((r) => r.data),

  deleteItem: (itemId: string) =>
    api
      .delete<MessageResponse>(`/userprofile/search-history/${itemId}`)
      .then((r) => r.data),

  clearAll: () =>
    api.delete<MessageResponse>('/userprofile/search-history').then((r) => r.data),
};

// MARK: - Favorites Endpoints

export const favoritesApi = {
  get: () =>
    api.get<FavoriteResponse[]>('/userprofile/favorites').then((r) => r.data),

  add: (body: AddFavoriteRequest) =>
    api.post<MessageResponse>('/userprofile/favorites', body).then((r) => r.data),

  remove: (productId: string) =>
    api.delete<MessageResponse>(`/userprofile/favorites/${productId}`).then((r) => r.data),

  toggle: (body: AddFavoriteRequest) =>
    api
      .post<ToggleFavoriteResponse>('/userprofile/favorites/toggle', body)
      .then((r) => r.data),

  check: (productId: string) =>
    api
      .get<IsFavoriteResponse>(`/userprofile/favorites/${productId}/check`)
      .then((r) => r.data),
};

// MARK: - Routines Endpoints

export const routinesApi = {
  getFeed: (limit = 20, search?: string) =>
    api
      .get<RoutineFeedItem[]>('/routines', { params: { limit, ...(search ? { search } : {}) } })
      .then((r) => r.data),

  getMy: () => api.get<RoutineFeedItem[]>('/routines/my').then((r) => r.data),

  getFavorites: (limit = 20) =>
    api
      .get<RoutineFeedItem[]>('/routines/favorites', { params: { limit } })
      .then((r) => r.data),

  getByUserId: (userId: string) =>
    api.get<RoutineFeedItem[]>(`/routines/user/${userId}`).then((r) => r.data),

  getLikedByUserId: (userId: string) =>
    api.get<RoutineFeedItem[]>(`/routines/user/${userId}/favorites`).then((r) => r.data),

  getDetail: (id: string) =>
    api.get<RoutineDetail>(`/routines/${id}`).then((r) => r.data),

  create: (body: CreateRoutineRequest) =>
    api.post<RoutineFeedItem>('/routines', body).then((r) => r.data),

  delete: (routineId: string) =>
    api.delete<MessageResponse>(`/routines/${routineId}`).then((r) => r.data),

  addComment: (routineId: string, text: string) =>
    api
      .post<RoutineCommentResponse>(`/routines/${routineId}/comments`, { text })
      .then((r) => r.data),

  toggleLike: (routineId: string) =>
    api
      .post<ToggleLikeResponse>(`/routines/${routineId}/likes/toggle`)
      .then((r) => r.data),

  uploadImage: async (formData: FormData): Promise<string> => {
    const response = await api.post<{ imageUrl: string }>(
      '/routines/upload-image',
      formData
    );
    return response.data.imageUrl;
  },
};

// MARK: - Profile Endpoints

export const profileApi = {
  uploadImage: async (formData: FormData): Promise<string> => {
    const response = await api.post<{ imageUrl: string }>(
      '/userprofile/profile-image',
      formData
    );
    return response.data.imageUrl;
  },

  update: (body: UpdateProfileRequest) =>
    api.put<MessageResponse>('/userprofile', body).then((r) => r.data),

  checkUsername: async (username: string): Promise<boolean> => {
    const res = await api.post<{ isAvailable: boolean }>(
      '/userprofile/check-username',
      { username }
    );
    return res.data.isAvailable;
  },

  getMyProfile: () =>
    api.get<UserProfileResponse>('/userprofile').then((r) => r.data),

  updateBio: (body: UpdateBioRequest) =>
    api.put<MessageResponse>('/userprofile/bio', body).then((r) => r.data),

  follow: (userId: string) =>
    api.post<MessageResponse>(`/userprofile/follow/${userId}`).then((r) => r.data),

  unfollow: (userId: string) =>
    api.delete<MessageResponse>(`/userprofile/follow/${userId}`).then((r) => r.data),

  getFollowers: () =>
    api.get<PublicUserProfileResponse[]>('/userprofile/followers').then((r) => r.data),

  getFollowing: () =>
    api.get<PublicUserProfileResponse[]>('/userprofile/following').then((r) => r.data),

  searchUsers: (query: string) =>
    api
      .get<PublicUserProfileResponse[]>('/userprofile/search', {
        params: { query, limit: 15 },
      })
      .then((r) => r.data),

  getPublicProfile: (username: string) =>
    api
      .get<PublicUserProfileResponse>(`/userprofile/public/${encodeURIComponent(username)}`)
      .then((r) => r.data),

  getPublicFollowers: (username: string) =>
    api
      .get<PublicUserProfileResponse[]>(
        `/userprofile/public/${encodeURIComponent(username)}/followers`
      )
      .then((r) => r.data),

  getPublicFollowing: (username: string) =>
    api
      .get<PublicUserProfileResponse[]>(
        `/userprofile/public/${encodeURIComponent(username)}/following`
      )
      .then((r) => r.data),

  getPublicFavorites: (username: string) =>
    api
      .get<FavoriteResponse[]>(
        `/userprofile/public/${encodeURIComponent(username)}/favorites`
      )
      .then((r) => r.data),
};

// MARK: - Ingredients Endpoints

export interface IngredientsFilters {
  search?: string;
  page?: number;
  pageSize?: number;
  minSafety?: number;
  maxSafety?: number;
  comedogenic?: boolean;
  safetyLabel?: string;
}

export const ingredientsApi = {
  get: (filters: IngredientsFilters = {}) => {
    const params: Record<string, string | number | boolean> = {
      page: filters.page ?? 1,
      pageSize: filters.pageSize ?? 50,
    };
    if (filters.search) params.search = filters.search;
    if (filters.minSafety !== undefined) params.minSafety = filters.minSafety;
    if (filters.maxSafety !== undefined) params.maxSafety = filters.maxSafety;
    if (filters.comedogenic) params.comedogenic = true;
    if (filters.safetyLabel) params.safetyLabel = filters.safetyLabel;

    return api.get<MatchedIngredient[]>('/ingredients', { params }).then((r) => r.data);
  },
};

export default api;
