import Foundation

// MARK: - Routine Models

struct RoutineProduct: Codable, Identifiable {
    let productId: String
    let name: String
    let brand: String?
    let imageUrl: String?

    var id: String { productId }
}

struct RoutineComment: Codable, Identifiable {
    let id: String
    let userName: String
    let text: String
    let createdAt: String?
}

struct RoutineFeedItem: Codable, Identifiable {
    let id: String
    let userName: String
    let skinType: String?
    let focus: String?
    let title: String
    let description: String?
    let coverImageUrl: String?
    let tags: [String]?
    var likeCount: Int
    var commentCount: Int
    var hasLiked: Bool
    let products: [RoutineProduct]?
    let createdAt: String?

    var productsList: [RoutineProduct] {
        products ?? []
    }
}

struct RoutineDetail: Codable, Identifiable {
    let id: String
    let userName: String
    let skinType: String?
    let focus: String?
    let title: String
    let description: String?
    let coverImageUrl: String?
    let routineType: String?
    let tags: [String]?
    var likeCount: Int
    var commentCount: Int
    var hasLiked: Bool
    let createdAt: String?
    let products: [RoutineProduct]
    var comments: [RoutineComment]
}

// MARK: - Request Models

struct RoutineProductRequest: Codable {
    let productId: String
    let name: String
    let brand: String?
    let imageUrl: String?
}

struct CreateRoutineRequest: Codable {
    let title: String
    let description: String?
    let skinType: String?
    let focus: String?
    let routineType: String?
    let tags: [String]?
    let coverImageUrl: String?
    let products: [RoutineProductRequest]
}

struct AddRoutineCommentRequest: Codable {
    let text: String
}

// MARK: - Response Models

struct RoutineCommentResponse: Codable {
    let id: String
    let userName: String
    let text: String
    let createdAt: String?
}

struct ToggleLikeResponse: Codable {
    let isLiked: Bool
    let likeCount: Int
}
