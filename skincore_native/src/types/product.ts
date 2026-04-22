// Ürün modelleri — Swift ProductModels.swift karşılığı

// image_urls hem string hem {fileUrl, fileName} formatında gelebilir
export type ProductImageUrl =
  | string
  | { fileUrl?: string; fileName?: string };

export function resolveImageUrl(item: ProductImageUrl | undefined): string | undefined {
  if (!item) return undefined;
  if (typeof item === 'string') return item || undefined;
  return item.fileUrl || undefined;
}

export function resolveFirstImageUrl(
  imageUrls?: ProductImageUrl[]
): string | undefined {
  if (!imageUrls || imageUrls.length === 0) return undefined;
  return resolveImageUrl(imageUrls[0]);
}

// MARK: - Ürün

export interface Product {
  id: string;
  name?: string;
  brand?: string;
  barcode?: string;
  image_urls?: ProductImageUrl[];
  product_ingredients?: string[];
  description?: string;
  rating?: number;
  review_count?: number;
}

// MARK: - İçerik (Ingredient)

export interface SkinCompatibility {
  good_for?: string[];
  bad_for?: string[];
}

export interface IngredientFunction {
  name?: string;
  uri?: string;
  is_dangerous?: boolean;
}

export interface MatchedIngredient {
  id?: string;
  inci_name?: string;
  name?: string;
  name_upper?: string;
  aliases?: string[];
  aliases_en?: string[];
  description?: string;
  description_en?: string;
  ewg_score?: string;
  functions?: IngredientFunction[] | string[];
  functions_en?: IngredientFunction[] | string[];
  safety_label?: string;
  safety_level?: number; // 0-4
  limited_eu?: boolean;
  limited_us?: boolean;
  safetymakeup_url?: string;
  skin_compatibility?: SkinCompatibility;
  skin_compatibility_en?: SkinCompatibility;
  comedogenic_rating?: number;
}

export interface IngredientMatchResult {
  originalString?: string;
  matchedIngredient?: MatchedIngredient;
  matchScore?: number;
  matchType?: string;
}

// Safety level 0–4 → 1–3 (güvenli / orta / riskli)
export function resolvedSafetyLevel(level: number | undefined): 0 | 1 | 2 | 3 {
  switch (level) {
    case 0:
    case 1:
      return 1;
    case 2:
      return 2;
    case 3:
    case 4:
      return 3;
    default:
      return 0;
  }
}

export function ingredientDisplayName(ing: MatchedIngredient): string {
  if (ing.inci_name) return ing.inci_name;
  if (ing.name_upper) return ing.name_upper;
  return ing.name ? ing.name.charAt(0).toUpperCase() + ing.name.slice(1) : '-';
}

// MARK: - Ürün + Zenginleştirilmiş İçerikler

export interface ProductWithEnrichedIngredients {
  id?: string;
  name?: string;
  brand?: string;
  barcode?: string;
  image_urls?: ProductImageUrl[];
  product_ingredients?: string[];
  enrichedIngredients?: IngredientMatchResult[];
}

// MARK: - Popüler Ürün

export interface PopularProductResponse {
  productId: string;
  productName?: string;
  imageUrl?: string;
  image_urls?: ProductImageUrl[];
}

export function resolvePopularImageUrl(item: PopularProductResponse): string | undefined {
  return item.imageUrl || resolveFirstImageUrl(item.image_urls);
}

// MARK: - Arama Geçmişi

export interface SearchHistoryResponse {
  id: string;
  query: string;
  productId?: string;
  productName?: string;
  category?: string;
  imageUrl?: string;
  searchedAt?: string;
  image_urls?: ProductImageUrl[];
}

export function resolveHistoryImageUrl(item: SearchHistoryResponse): string | undefined {
  return item.imageUrl || resolveFirstImageUrl(item.image_urls);
}

export interface AddSearchHistoryRequest {
  query: string;
  productId?: string;
  productName?: string;
  category?: string;
}

// MARK: - Favoriler

export interface FavoriteResponse {
  id: string;
  productId: string;
  productName: string;
  productBrand?: string;
  productImageURL?: string;
  addedAt?: string;
  image_urls?: ProductImageUrl[];
}

export function resolveFavoriteImageUrl(item: FavoriteResponse): string | undefined {
  return item.productImageURL || resolveFirstImageUrl(item.image_urls);
}

export interface AddFavoriteRequest {
  productId: string;
  productName: string;
  productBrand?: string;
  productImageURL?: string;
}

export interface ToggleFavoriteResponse {
  isFavorite: boolean;
  message: string;
}

export interface IsFavoriteResponse {
  isFavorite: boolean;
}
