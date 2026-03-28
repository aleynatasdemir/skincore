import Foundation

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = nil }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode(Bool.self) { value = v }
        else { value = nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value as? Int { try container.encode(v) }
        else if let v = value as? Double { try container.encode(v) }
        else if let v = value as? String { try container.encode(v) }
        else if let v = value as? Bool { try container.encode(v) }
        else { try container.encodeNil() }
    }
}

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

struct IngredientMetrics: Codable {
    let comedogenicRating: Int?
    let ewgScore: String?
    let safetyLabel: String?
    let safetyLevel: Int?

    enum CodingKeys: String, CodingKey {
        case comedogenicRating = "comedogenic_rating"
        case ewgScore          = "ewg_score"
        case safetyLabel       = "safety_label"
        case safetyLevel       = "safety_level"
    }
}

struct SkinCompatibility: Codable {
    let goodFor: [String]?
    let badFor: [String]?

    enum CodingKeys: String, CodingKey {
        case goodFor = "good_for"
        case badFor  = "bad_for"
    }
}

struct MatchedIngredient: Codable, Identifiable {
    let id: String?
    let name: String?
    let nameUpper: String?
    let inciName: String?
    let aliases: [String]?
    let description: String?
    let ewgScore: String?
    let functions: [String]?
    let safetyLabel: String?
    let safetyLevel: Int?
    let limitedEu: Bool?
    let limitedUs: Bool?
    let comedogenic: AnyCodable?
    let metrics: IngredientMetrics?
    let skinCompatibility: SkinCompatibility?

    /// Düzgün formatlı isim: önce inci_name, sonra name_upper, sonra name
    var displayName: String {
        if let inci = inciName, !inci.isEmpty { return inci }
        if let upper = nameUpper, !upper.isEmpty { return upper }
        return name?.capitalized ?? "-"
    }

    /// safety_level: önce metrics'ten, sonra doğrudan alandan, sonra label'dan türet
    var resolvedSafetyLevel: Int {
        if let mLvl = metrics?.safetyLevel, mLvl > 0 { return mLvl }
        let lvl = safetyLevel ?? 0
        if lvl > 0 { return lvl }
        let label = (metrics?.safetyLabel ?? safetyLabel)?.lowercased() ?? ""
        switch label {
        case "güvenli", "safe", "tamamen güvenli":                      return 1
        case "orta", "moderate", "dikkatli", "caution",
             "kabul edilebilir":                                         return 2
        case "kaçın", "avoid", "tehlikeli", "dangerous":               return 3
        default:                                                        return 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameUpper          = "name_upper"
        case inciName           = "inci_name"
        case aliases
        case description
        case ewgScore           = "ewg_score"
        case functions
        case safetyLabel        = "safety_label"
        case safetyLevel        = "safety_level"
        case limitedEu          = "limited_eu"
        case limitedUs          = "limited_us"
        case comedogenic
        case metrics
        case skinCompatibility  = "skin_compatibility"
    }
}

struct IngredientMatchResult: Codable, Identifiable {
    var id: String { originalString ?? UUID().uuidString }
    let originalString: String?
    let matchedIngredient: MatchedIngredient?
    let matchScore: Double?
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
