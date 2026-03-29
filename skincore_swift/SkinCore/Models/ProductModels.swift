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

struct IngredientFunction: Codable {
    let name: String?
    let uri: String?
    let isDangerous: Bool?

    init(name: String?, uri: String? = nil, isDangerous: Bool? = nil) {
        self.name = name
        self.uri = uri
        self.isDangerous = isDangerous
    }

    init(from decoder: Decoder) throws {
        // String formatını destekle (örn: "Nemlendirici", "Boya")
        if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
            name = stringValue
            uri = nil
            isDangerous = nil
            return
        }
        
        // Dictionary ({name: "...", uri: "..."}) formatını destekle
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        isDangerous = try container.decodeIfPresent(Bool.self, forKey: .isDangerous)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case uri
        case isDangerous = "is_dangerous"
    }
}

struct MatchedIngredient: Codable, Identifiable {
    let id: String?
    let inciName: String?
    let name: String?
    let nameUpper: String?
    let aliases: [String]?
    let description: String?
    let ewgScore: String?
    let functions: [IngredientFunction]?
    let safetyLabel: String?
    let safetyLevel: Int?
    let limitedEu: Bool?
    let limitedUs: Bool?
    let safetymakeupUrl: String?
    let skinCompatibility: SkinCompatibility?
    let comedogenicRating: Int?

    /// Düzgün formatlı isim: önce inci_name, sonra name_upper, sonra name → capitalized
    var displayName: String {
        if let inci = inciName, !inci.isEmpty { return inci }
        if let upper = nameUpper, !upper.isEmpty { return upper }
        return name?.capitalized ?? "-"
    }

    // Convenience properties to stay backward compatible
    var goodFor: [String]? { skinCompatibility?.goodFor }
    var badFor: [String]? { skinCompatibility?.badFor }

    /// 0–4 DB değerlerini görünüm badge'i için 1-3 aralığına indirger
    var resolvedSafetyLevel: Int {
        switch safetyLevel {
        case 0, 1: return 1   // güvenli
        case 2:    return 2   // orta
        case 3, 4: return 3   // riskli
        default:   return 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case inciName           = "inci_name"
        case name
        case nameUpper          = "name_upper"
        case description
        case aliases
        case ewgScore           = "ewg_score"
        case functions
        case safetyLabel        = "safety_label"
        case safetyLevel        = "safety_level"
        case limitedEu          = "limited_eu"
        case limitedUs          = "limited_us"
        case safetymakeupUrl    = "safetymakeup_url"
        case skinCompatibility  = "skin_compatibility"
        case comedogenicRating  = "comedogenic_rating"
    }
}

struct SkinCompatibility: Codable {
    let goodFor: [String]?
    let badFor: [String]?
    
    enum CodingKeys: String, CodingKey {
        case goodFor = "good_for"
        case badFor = "bad_for"
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
