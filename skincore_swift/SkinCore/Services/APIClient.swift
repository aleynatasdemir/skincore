import Foundation

class APIClient {
    static let shared = APIClient()
    
    // TODO: Production'da gerçek URL'ye değiştir
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:5192/api"
    #else
    private let baseURL = "http://192.168.0.15:5192/api"
    #endif
    
    private init() {}
    
    // MARK: - Generic Request
    
    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add JWT token if authenticated
        if authenticated, let token = KeychainService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode body
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(MessageResponse.self, from: data) {
                throw APIClientError.serverError(errorResponse.message)
            }
            throw APIClientError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Auth Endpoints
    
    func register(email: String, password: String, fullName: String?) async throws -> MessageResponse {
        let body = RegisterRequest(email: email, password: password, fullName: fullName)
        return try await request(endpoint: "/auth/register", method: "POST", body: body)
    }
    
    func verifyEmail(email: String, code: String) async throws -> AuthResponse {
        let body = VerifyEmailRequest(email: email, code: code)
        return try await request(endpoint: "/auth/verify-email", method: "POST", body: body)
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        return try await request(endpoint: "/auth/login", method: "POST", body: body)
    }
    
    func appleSignIn(identityToken: String, fullName: String?, email: String?) async throws -> AuthResponse {
        let body = AppleSignInRequestBody(identityToken: identityToken, fullName: fullName, email: email)
        return try await request(endpoint: "/auth/apple", method: "POST", body: body)
    }
    
    func resendCode(email: String) async throws -> MessageResponse {
        let body = ResendCodeRequest(email: email)
        return try await request(endpoint: "/auth/resend-code", method: "POST", body: body)
    }
    
    func refreshToken() async throws -> AuthResponse {
        guard let token = KeychainService.shared.getRefreshToken() else {
            throw APIClientError.noRefreshToken
        }
        let body = RefreshTokenRequest(refreshToken: token)
        return try await request(endpoint: "/auth/refresh", method: "POST", body: body)
    }
    
    func getMe() async throws -> UserResponse {
        return try await request(endpoint: "/auth/me", authenticated: true)
    }

    // MARK: - Product Endpoints

    func searchProductsByName(query: String, maxResults: Int = 5) async throws -> [Product] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(
            endpoint: "/products/search/name?query=\(encodedQuery)&maxResults=\(maxResults)"
        )
    }

    func getProductDetails(id: String) async throws -> ProductWithEnrichedIngredients {
        return try await request(endpoint: "/products/\(id)")
    }
}

// MARK: - Errors

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz URL"
        case .invalidResponse: return "Geçersiz yanıt"
        case .httpError(let code): return "HTTP hatası: \(code)"
        case .serverError(let message): return message
        case .noRefreshToken: return "Oturumunuz sona ermiş"
        }
    }
}
