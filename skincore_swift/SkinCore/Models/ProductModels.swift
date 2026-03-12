import Foundation

// MARK: - Product Response Models

// image_urls hem ["url"] hem de [{fileUrl, fileName}] formatında gelebilir
struct ProductImageUrl: Codable {
    let fileUrl: String?
    let fileName: String?

    init(fileUrl: String?, fileName: String? = nil) {
        self.fileUrl = fileUrl
        self.fileName = fileName
    }

    init(from decoder: Decoder) throws {
        // String formatı: "https://..."
        if let urlString = try? decoder.singleValueContainer().decode(String.self) {
            fileUrl = urlString
            fileName = nil
            return
        }
        // Object formatı: {fileUrl: "...", fileName: "..."}
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileUrl  = try container.decodeIfPresent(String.self, forKey: .fileUrl)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
    }

    enum CodingKeys: String, CodingKey {
        case fileUrl
        case fileName
    }
}

struct Product: Codable, Identifiable {
    let id: String
    let name: String?
    let brand: String?
    let barcode: String?
    let imageUrls: [ProductImageUrl]?
    let productIngredients: [String]?
    let description: String?
    let rating: Double?
    let reviewCount: Int?

    // İlk resmin URL'sini döner
    var firstImageUrl: String? { imageUrls?.first?.fileUrl }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case barcode
        case imageUrls       = "image_urls"
        case productIngredients = "product_ingredients"
        case description
        case rating
        case reviewCount     = "review_count"
    }
}

// MARK: - Ingredient Models

struct IngredientFunction: Codable {
    let name: String?
    let uri: String?
    let isDangerous: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case uri
        case isDangerous = "is_dangerous"
    }
}

struct IngredientMetrics: Codable {
    let safetyLevel: Int?
    let safetyLabel: String?
    let ewgScore: String?
    let comedogenicRating: Int?

    enum CodingKeys: String, CodingKey {
        case safetyLevel = "safety_level"
        case safetyLabel = "safety_label"
        case ewgScore = "ewg_score"
        case comedogenicRating = "comedogenic_rating"
    }
}

struct MatchedIngredient: Codable, Identifiable {
    let id: String?
    let name: String?
    let nameUpper: String?
    let description: String?
    let functions: [String]? // Updated to [String] to handle flexible data
    let metrics: IngredientMetrics?

    /// Düzgün formatlı isim: önce name_upper, sonra name → capitalized
    var displayName: String {
        if let upper = nameUpper, !upper.isEmpty { return upper }
        return name?.capitalized ?? "-"
    }

    /// safety_level 0 veya nil ise safety_label'dan türet
    var resolvedSafetyLevel: Int {
        let lvl = metrics?.safetyLevel ?? 0
        if lvl > 0 { return lvl }
        switch metrics?.safetyLabel?.lowercased() {
        case "güvenli", "safe", "tamamen güvenli":          return 1
        case "orta", "moderate", "dikkatli", "caution":    return 2
        case "kaçın", "avoid", "tehlikeli", "dangerous":   return 3
        default:                                            return 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameUpper       = "name_upper"
        case description
        case functions
        case metrics
    }
}

struct IngredientMatchResult: Codable, Identifiable {
    var id: String { originalString ?? UUID().uuidString }
    let originalString: String?
    let matchedIngredient: MatchedIngredient?
    let matchScore: Int?
    let matchType: String?
}

// MARK: - Product with Enriched Ingredients Response

// MARK: - Popular & Search History Models

struct PopularProductResponse: Codable, Identifiable {
    let productId: String
    let productName: String?
    let imageUrl: String?
    // Some endpoints may include image_urls (array) as well — accept both formats
    let imageUrls: [ProductImageUrl]?

    /// Prefer explicit imageUrl, fall back to first item in imageUrls
    var resolvedImageUrl: String? { imageUrl ?? imageUrls?.first?.fileUrl }

    var id: String { productId }

    enum CodingKeys: String, CodingKey {
        case productId   = "productId"
        case productName = "productName"
        case imageUrl    = "imageUrl"
        case imageUrls   = "image_urls"
    }
}

struct SearchHistoryResponse: Codable, Identifiable {
    let id: String
    let query: String
    let productId: String?
    let productName: String?
    let category: String?
    let imageUrl: String?
    let searchedAt: String?
    let imageUrls: [ProductImageUrl]?

    var resolvedImageUrl: String? { imageUrl ?? imageUrls?.first?.fileUrl }

    enum CodingKeys: String, CodingKey {
        case id
        case query
        case productId
        case productName
        case category
        case imageUrl
        case searchedAt
        case imageUrls = "image_urls"
    }
}

struct AddSearchHistoryRequest: Codable {
    let query: String
    let productId: String?
    let productName: String?
    let category: String?
}

// MARK: - Favorite Models

struct FavoriteResponse: Codable, Identifiable {
    let id: String
    let productId: String
    let productName: String
    let productBrand: String?
    let productImageURL: String?
    let addedAt: String?
    // accept image_urls from backend too
    let imageUrls: [ProductImageUrl]?

    var resolvedImageUrl: String? { productImageURL ?? imageUrls?.first?.fileUrl }

    enum CodingKeys: String, CodingKey {
        case id
        case productId
        case productName
        case productBrand
        case productImageURL
        case addedAt
        case imageUrls = "image_urls"
    }
}

struct AddFavoriteRequest: Codable {
    let productId: String
    let productName: String
    let productBrand: String?
    let productImageURL: String?

    enum CodingKeys: String, CodingKey {
        case productId
        case productName
        case productBrand
        case productImageURL
    }
}

struct ToggleFavoriteResponse: Codable {
    let isFavorite: Bool
    let message: String
}

struct IsFavoriteResponse: Codable {
    let isFavorite: Bool
}

// MARK: - Product with Enriched Ingredients Response

struct ProductWithEnrichedIngredients: Codable {
    let id: String?
    let name: String?
    let brand: String?
    let barcode: String?
    let imageUrls: [ProductImageUrl]?
    let productIngredients: [String]?
    let enrichedIngredients: [IngredientMatchResult]?

    var firstImageUrl: String? { imageUrls?.first?.fileUrl }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case barcode
        case imageUrls          = "image_urls"
        case productIngredients = "product_ingredients"
        case enrichedIngredients
    }
}
