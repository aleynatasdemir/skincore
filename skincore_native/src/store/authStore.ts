import { create } from 'zustand';
import { authApi, TokenStorage, extractErrorMessage } from '../api/apiClient';
import type { UserResponse, AuthResponse } from '../types/auth';

interface AuthState {
  isAuthenticated: boolean;
  isInitializing: boolean;
  currentUser: UserResponse | null;
  isLoading: boolean;
  errorMessage: string | null;

  // Navigation state (Swift AuthViewModel karşılığı)
  showVerifyEmail: boolean;
  pendingEmail: string;
  resetPasswordCompleted: boolean;

  // Computed
  needsUsername: boolean;

  // Actions
  checkAuth: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, fullName?: string) => Promise<void>;
  verifyEmail: (code: string) => Promise<void>;
  resendCode: () => Promise<void>;
  forgotPassword: (email: string) => Promise<void>;
  resetPassword: (code: string, newPassword: string) => Promise<void>;
  setupUsername: (username: string) => Promise<void>;
  appleSignIn: (identityToken: string, fullName?: string, email?: string) => Promise<void>;
  updateNotifications: (enabled: boolean) => Promise<void>;
  deleteAccount: () => Promise<boolean>;
  logout: () => Promise<void>;
  clearError: () => void;
  setPendingEmail: (email: string) => void;
  setShowVerifyEmail: (show: boolean) => void;
}

function saveAuth(response: AuthResponse) {
  return TokenStorage.saveTokens(response);
}

export const useAuthStore = create<AuthState>((set, get) => ({
  isAuthenticated: false,
  isInitializing: true,
  currentUser: null,
  isLoading: false,
  errorMessage: null,
  showVerifyEmail: false,
  pendingEmail: '',
  resetPasswordCompleted: false,

  get needsUsername() {
    const user = get().currentUser;
    return get().isAuthenticated && (!user?.username || user.username.trim() === '');
  },

  // MARK: - Check Auth (app başlangıcı)
  checkAuth: async () => {
    const token = await TokenStorage.getAccessToken();
    if (!token) {
      set({ isInitializing: false });
      return;
    }
    try {
      const user = await authApi.getMe();
      set({ currentUser: user, isAuthenticated: true, isInitializing: false });
    } catch {
      // Token süresi dolmuş olabilir, refresh dene
      try {
        const refreshToken = await TokenStorage.getRefreshToken();
        if (!refreshToken) throw new Error('No refresh token');
        const response = await authApi.refreshToken(refreshToken);
        await saveAuth(response);
        set({ currentUser: response.user, isAuthenticated: true, isInitializing: false });
      } catch {
        await TokenStorage.clearAll();
        set({ isAuthenticated: false, isInitializing: false });
      }
    }
  },

  // MARK: - Login
  login: async (email, password) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const response = await authApi.login({ email, password });
      await saveAuth(response);
      set({ currentUser: response.user, isAuthenticated: true, isLoading: false });
    } catch (error) {
      const msg = extractErrorMessage(error, 'Giriş yapılamadı.');
      // E-posta doğrulanmamışsa verify sayfasına yönlendir
      if (msg.includes('doğrulayın') || msg.includes('verify')) {
        set({ pendingEmail: email, showVerifyEmail: true, isLoading: false });
        // Kodu tekrar gönder
        try { await authApi.resendCode(email); } catch {}
      } else {
        set({ errorMessage: msg, isLoading: false });
      }
    }
  },

  // MARK: - Register
  register: async (email, password, fullName) => {
    set({ isLoading: true, errorMessage: null });
    try {
      await authApi.register({ email, password, fullName });
      set({ pendingEmail: email, showVerifyEmail: true, isLoading: false });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Kayıt olunamadı.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Verify Email
  verifyEmail: async (code) => {
    const { pendingEmail } = get();
    set({ isLoading: true, errorMessage: null });
    try {
      const response = await authApi.verifyEmail({ email: pendingEmail, code });
      await saveAuth(response);
      set({
        currentUser: response.user,
        isAuthenticated: true,
        showVerifyEmail: false,
        isLoading: false,
      });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Doğrulama başarısız.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Resend Code
  resendCode: async () => {
    const { pendingEmail } = get();
    set({ isLoading: true, errorMessage: null });
    try {
      await authApi.resendCode(pendingEmail);
    } catch (error) {
      set({ errorMessage: extractErrorMessage(error) });
    }
    set({ isLoading: false });
  },

  // MARK: - Forgot Password
  forgotPassword: async (email) => {
    set({ isLoading: true, errorMessage: null, resetPasswordCompleted: false });
    try {
      await authApi.forgotPassword(email);
      set({ pendingEmail: email, isLoading: false });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Kod gönderilemedi.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Reset Password
  resetPassword: async (code, newPassword) => {
    const { pendingEmail } = get();
    set({ isLoading: true, errorMessage: null });
    try {
      await authApi.resetPassword({ email: pendingEmail, code, newPassword });
      set({ resetPasswordCompleted: true, pendingEmail: '', isLoading: false });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Şifre sıfırlanamadı.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Setup Username
  setupUsername: async (username) => {
    set({ isLoading: true, errorMessage: null });
    try {
      await authApi.getMe(); // token geçerli mi kontrol
      // profile update sonra getMe
      const { profileApi } = await import('../api/apiClient');
      await profileApi.update({ username });
      const user = await authApi.getMe();
      set({ currentUser: user, isLoading: false });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Kullanıcı adı ayarlanamadı.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Apple Sign In
  appleSignIn: async (identityToken, fullName, email) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const response = await authApi.appleSignIn({ identityToken, fullName, email });
      await saveAuth(response);
      set({ currentUser: response.user, isAuthenticated: true, isLoading: false });
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Apple ile giriş başarısız.'),
        isLoading: false,
      });
    }
  },

  // MARK: - Update Notifications
  updateNotifications: async (enabled) => {
    try {
      await authApi.updateNotifications(enabled);
      const user = await authApi.getMe();
      set({ currentUser: user });
    } catch {
      // Sessizce geç
    }
  },

  // MARK: - Delete Account
  deleteAccount: async () => {
    set({ isLoading: true, errorMessage: null });
    try {
      await authApi.deleteAccount();
      await TokenStorage.clearAll();
      set({
        isAuthenticated: false,
        currentUser: null,
        isLoading: false,
      });
      return true;
    } catch (error) {
      set({
        errorMessage: extractErrorMessage(error, 'Hesap silinemedi.'),
        isLoading: false,
      });
      return false;
    }
  },

  // MARK: - Logout
  logout: async () => {
    await TokenStorage.clearAll();
    set({ isAuthenticated: false, currentUser: null });
  },

  clearError: () => set({ errorMessage: null }),
  setPendingEmail: (email) => set({ pendingEmail: email }),
  setShowVerifyEmail: (show) => set({ showVerifyEmail: show }),
}));
