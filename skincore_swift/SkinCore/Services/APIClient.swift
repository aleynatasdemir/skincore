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

    func searchProductsByImage(imageData: Data, ocrText: String?, maxResults: Int = 5) async throws -> [Product] {
        guard let url = URL(string: "\(baseURL)/products/search/image") else {
            throw APIClientError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // ocrText field
        if let ocrText = ocrText, !ocrText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ocrText\"\r\n\r\n".data(using: .utf8)!)
            body.append(ocrText.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        // maxResults field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"maxResults\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(maxResults)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode([Product].self, from: data)
    }

    // MARK: - Popular Endpoints

    func getPopularProducts(limit: Int = 10) async throws -> [PopularProductResponse] {
        return try await request(endpoint: "/popular?limit=\(limit)")
    }

    // MARK: - Search History Endpoints

    func getSearchHistory(limit: Int = 20) async throws -> [SearchHistoryResponse] {
        return try await request(endpoint: "/userprofile/search-history?limit=\(limit)", authenticated: true)
    }

    func addSearchHistory(_ req: AddSearchHistoryRequest) async throws -> MessageResponse {
        return try await request(endpoint: "/userprofile/search-history", method: "POST", body: req, authenticated: true)
    }

    func deleteSearchHistoryItem(itemId: String) async throws -> MessageResponse {
        return try await request(endpoint: "/userprofile/search-history/\(itemId)", method: "DELETE", authenticated: true)
    }

    func clearSearchHistory() async throws -> MessageResponse {
        return try await request(endpoint: "/userprofile/search-history", method: "DELETE", authenticated: true)
    }

    // MARK: - Favorites Endpoints

    func getFavorites() async throws -> [FavoriteResponse] {
        return try await request(endpoint: "/userprofile/favorites", authenticated: true)
    }

    func addFavorite(_ req: AddFavoriteRequest) async throws -> MessageResponse {
        return try await request(endpoint: "/userprofile/favorites", method: "POST", body: req, authenticated: true)
    }

    func removeFavorite(productId: String) async throws -> MessageResponse {
        return try await request(endpoint: "/userprofile/favorites/\(productId)", method: "DELETE", authenticated: true)
    }

    func toggleFavorite(_ req: AddFavoriteRequest) async throws -> ToggleFavoriteResponse {
        return try await request(endpoint: "/userprofile/favorites/toggle", method: "POST", body: req, authenticated: true)
    }

    func checkFavorite(productId: String) async throws -> IsFavoriteResponse {
        return try await request(endpoint: "/userprofile/favorites/\(productId)/check", authenticated: true)
    }

    // MARK: - Routines (Social) Endpoints

    func getRoutineFeed(limit: Int = 20, search: String? = nil) async throws -> [RoutineFeedItem] {
        var endpoint = "/routines?limit=\(limit)"
        if let search = search, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            endpoint += "&search=\(encoded)"
        }
        return try await request(endpoint: endpoint, authenticated: true)
    }

    func getMyRoutines() async throws -> [RoutineFeedItem] {
        return try await request(endpoint: "/routines/my", authenticated: true)
    }

    func getRoutineDetail(id: String) async throws -> RoutineDetail {
        return try await request(endpoint: "/routines/\(id)", authenticated: true)
    }

    func createRoutine(_ req: CreateRoutineRequest) async throws -> RoutineFeedItem {
        return try await request(endpoint: "/routines", method: "POST", body: req, authenticated: true)
    }

    func addRoutineComment(routineId: String, text: String) async throws -> RoutineCommentResponse {
        let body = AddRoutineCommentRequest(text: text)
        return try await request(endpoint: "/routines/\(routineId)/comments", method: "POST", body: body, authenticated: true)
    }

    func toggleRoutineLike(routineId: String) async throws -> ToggleLikeResponse {
        return try await request(endpoint: "/routines/\(routineId)/likes/toggle", method: "POST", authenticated: true)
    }

    func uploadImage(data: Data) async throws -> String {
        guard let url = URL(string: "\(baseURL)/routines/upload-image") else {
            throw APIClientError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = KeychainService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct UploadResponse: Codable { let imageUrl: String }
        let result = try JSONDecoder().decode(UploadResponse.self, from: responseData)
        return result.imageUrl
    }

    // MARK: - Ingredients Endpoints

    func getIngredients(search: String? = nil, page: Int = 1, pageSize: Int = 50, minSafety: Int? = nil, maxSafety: Int? = nil, comedogenic: Bool? = nil) async throws -> [MatchedIngredient] {
        var endpoint = "/ingredients?page=\(page)&pageSize=\(pageSize)"
        if let search = search, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            endpoint += "&search=\(encoded)"
        }
        if let min = minSafety {
            endpoint += "&minSafety=\(min)"
        }
        if let max = maxSafety {
            endpoint += "&maxSafety=\(max)"
        }
        if let com = comedogenic, com {
            endpoint += "&comedogenic=true"
        }
        return try await request(endpoint: endpoint)
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
