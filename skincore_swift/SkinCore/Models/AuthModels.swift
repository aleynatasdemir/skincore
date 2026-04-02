import Foundation

// MARK: - Request Models

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct VerifyEmailRequest: Codable {
    let email: String
    let code: String
}

struct AppleSignInRequestBody: Codable {
    let identityToken: String
    let fullName: String?
    let email: String?
}

struct ResendCodeRequest: Codable {
    let email: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let email: String
    let code: String
    let newPassword: String
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: UserResponse
}

struct UserResponse: Codable, Identifiable {
    let id: String
    let email: String
    let fullName: String?
    let username: String?
    let profileImageUrl: String?
    let authProvider: String
    let isEmailVerified: Bool
    let createdAt: String
}

struct MessageResponse: Codable {
    let message: String
}

// MARK: - Error Response

struct APIError: Codable {
    let message: String?
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}
