// Auth modelleri — Swift AuthModels.swift karşılığı

export interface RegisterRequest {
  email: string;
  password: string;
  fullName?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface VerifyEmailRequest {
  email: string;
  code: string;
}

export interface AppleSignInRequest {
  identityToken: string;
  fullName?: string;
  email?: string;
}

export interface ResendCodeRequest {
  email: string;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  code: string;
  newPassword: string;
}

export interface ChangePasswordRequest {
  currentPassword: string;
  newPassword: string;
}

// Responses

export interface UserResponse {
  id: string;
  email: string;
  fullName?: string;
  username?: string;
  profileImageUrl?: string;
  authProvider: string;
  isEmailVerified: boolean;
  notificationsEnabled: boolean;
  isAdmin: boolean;
  skinType?: string;
  createdAt: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: UserResponse;
}

export interface MessageResponse {
  message: string;
}
