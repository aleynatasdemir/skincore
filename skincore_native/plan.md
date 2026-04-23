# SkinCore – React Native Geçiş Planı

> Swift iOS uygulamasının (`skincore_swift`) birebir React Native karşılığı.  
> Hedef: **Expo + React Native** ile iOS **ve** Android'de çalışan, hiçbir özellik eksik olmayan tam fonksiyonel uygulama.

---

## 0. Teknoloji Seçimleri

| Konu | Swift (mevcut) | React Native karşılığı |
|---|---|---|
| Framework | SwiftUI | **Expo (Managed Workflow)** |
| Navigasyon | NavigationStack + TabView | **React Navigation v7** (Stack + BottomTabs) |
| State yönetimi | @StateObject / @EnvironmentObject | **Zustand** (auth, subscription store) |
| Token saklama | Keychain (Security framework) | **expo-secure-store** |
| HTTP istekleri | URLSession (async/await) | **axios** |
| Kamera/OCR | AVFoundation (custom kamera) | **expo-camera** + **react-native-vision-camera** (gelişmiş tarama için) |
| Galeri seçimi | PhotosUI (PhotosPicker) | **expo-image-picker** |
| Görsel yükleme / cache | Kingfisher | **expo-image** (caching built-in) |
| In-App Purchase | StoreKit 2 | **react-native-purchases (RevenueCat)** |
| Lokalizasyon (TR/EN) | LanguageManager + L10nKey | **i18next + react-i18next** |
| Apple Sign In | AuthenticationServices | **expo-apple-authentication** |
| Animasyon | SwiftUI Animation | **react-native-reanimated** |
| Debounce (arama) | Combine `.debounce` | **lodash.debounce** veya custom hook |

---

## 1. Klasör Yapısı (hedef)

```
skincore_native/
├── app/                        ← Expo Router screen dosyaları (alternatif: src/screens)
│   ├── (auth)/
│   │   ├── login.tsx
│   │   ├── register.tsx
│   │   ├── verify-email.tsx
│   │   ├── forgot-password.tsx
│   │   ├── reset-password.tsx
│   │   └── username-setup.tsx
│   ├── (tabs)/
│   │   ├── _layout.tsx         ← BottomTabNavigator
│   │   ├── index.tsx           ← HomeScreen
│   │   ├── ingredients.tsx     ← IngredientAnalysisScreen
│   │   ├── scan.tsx            ← ScanScreen
│   │   ├── social.tsx          ← SocialFeedScreen
│   │   └── profile.tsx         ← ProfileScreen
│   └── _layout.tsx             ← RootLayout (auth guard)
├── src/
│   ├── api/
│   │   └── apiClient.ts        ← Tüm API çağrıları (axios)
│   ├── store/
│   │   ├── authStore.ts        ← Zustand: user, isAuthenticated, isInitializing
│   │   └── subscriptionStore.ts ← isPremium, dailyScanCount
│   ├── hooks/
│   │   ├── useDebounce.ts
│   │   └── useSkinType.ts
│   ├── i18n/
│   │   ├── index.ts            ← i18next init
│   │   ├── tr.json             ← Türkçe çeviriler (SocialModels L10nKey → JSON)
│   │   └── en.json             ← İngilizce çeviriler
│   ├── theme/
│   │   └── colors.ts           ← #D4728C, #1A1A2E, #FFF0F0 paleti
│   ├── components/
│   │   ├── common/
│   │   │   ├── CachedImage.tsx
│   │   │   ├── AvatarView.tsx
│   │   │   ├── SafetyBadge.tsx
│   │   │   └── FeatureRow.tsx
│   │   ├── home/
│   │   │   ├── PopularProductCard.tsx
│   │   │   ├── HistoryRow.tsx
│   │   │   ├── SearchResultsPanel.tsx
│   │   │   └── QuickActionCard.tsx
│   │   ├── scan/
│   │   │   ├── ScanResultCard.tsx
│   │   │   ├── ProductDetailSheet.tsx
│   │   │   └── IngredientRow.tsx
│   │   ├── social/
│   │   │   ├── RoutineFeedCard.tsx
│   │   │   └── CommentItem.tsx
│   │   └── profile/
│   │       ├── ProfileHeader.tsx
│   │       ├── RoutineGridCell.tsx
│   │       └── FavoriteGridCell.tsx
│   └── types/
│       ├── auth.ts             ← AuthResponse, UserResponse vb.
│       ├── product.ts          ← Product, MatchedIngredient vb.
│       └── social.ts           ← RoutineFeedItem, PublicUserProfileResponse vb.
├── assets/
│   └── images/                 ← Logo, card arka planları vb.
├── app.json
├── package.json
└── tsconfig.json
```

---

## 2. Adım Adım Uygulama Planı

### ✅ ADIM 1 – Proje Kurulumu
- [x] `npx create-expo-app@latest skincore_native --template blank-typescript`
- [x] Bağımlılıkları kur:
  ```
  expo-router react-navigation/native react-navigation/bottom-tabs
  react-navigation/native-stack
  axios zustand
  expo-secure-store
  expo-camera expo-image-picker
  expo-image
  expo-apple-authentication
  react-native-reanimated
  react-native-gesture-handler
  react-native-safe-area-context
  react-native-screens
  i18next react-i18next
  react-native-purchases
  lodash @types/lodash
  ```
- [x] `tsconfig.json`, `babel.config.js` yapılandır.
- [x] `app.json`: bundleId, permissions (kamera, galeri).

---

### ✅ ADIM 2 – Tema & Renkler (`src/theme/colors.ts`)
Swift'teki `Color(hex:)` extension karşılığı:
```ts
export const Colors = {
  primary: '#D4728C',      // Ana pembe
  dark: '#1A1A2E',         // Başlık metni
  background: '#FFF0F0',   // Sayfa arka planı
  surface: '#FFFFFF',
  muted: '#9CA3AF',
  border: '#E5E7EB',
  accent: '#7B5455',
  danger: '#EF4444',
  softPink: '#F9D6D6',
};
```

---

### ✅ ADIM 3 – Lokalizasyon (`src/i18n/`)
`SocialModels.swift` içindeki 200+ `L10nKey` değerini TR ve EN olarak iki JSON dosyasına dönüştür.  
`i18next` + `expo-localization` ile cihaz dilini algıla, `tr` veya `en` seç.

---

### ✅ ADIM 4 – Tip Tanımları (`src/types/`)

#### `auth.ts`
```ts
export interface UserResponse { id, email, fullName?, username?, profileImageUrl?, authProvider, isEmailVerified, notificationsEnabled, isAdmin, skinType?, createdAt }
export interface AuthResponse { accessToken, refreshToken, user: UserResponse }
export interface MessageResponse { message: string }
```

#### `product.ts`
```ts
export interface Product { id, name?, brand?, barcode?, image_urls?, product_ingredients?, description?, rating?, review_count? }
export interface MatchedIngredient { id?, inci_name?, name?, safety_label?, safety_level?, limited_eu?, limited_us?, comedogenic_rating?, functions?, skin_compatibility?, ... }
export interface ProductWithEnrichedIngredients { id?, name?, brand?, image_urls?, enrichedIngredients?: IngredientMatchResult[] }
export interface FavoriteResponse { id, productId, productName, productBrand?, productImageURL?, addedAt?, image_urls? }
export interface SearchHistoryResponse { id, query, productId?, productName?, category?, imageUrl?, searchedAt?, image_urls? }
export interface PopularProductResponse { productId, productName?, imageUrl?, image_urls? }
```

#### `social.ts`
```ts
export interface RoutineFeedItem { id, userId, username, displayName, profileImageUrl?, title, description?, coverImageUrl?, type, products: RoutineProduct[], likeCount, commentCount, isLiked, createdAt }
export interface PublicUserProfileResponse { id, username, fullName?, profileImageUrl?, bio?, followerCount, followingCount, isFollowing }
export interface UserProfileResponse { ... + skinType, email }
```

---

### ✅ ADIM 5 – API Katmanı (`src/api/apiClient.ts`)
Swift `APIClient.swift`'in birebir TypeScript karşılığı. `axios` instance:
- `baseURL`: `http://91.132.49.137:5192/api`
- Request interceptor: `Authorization: Bearer <accessToken>` ekle.
- Response interceptor: 401 → refresh token → retry.

**Endpoint grupları:**
- **Auth**: `POST /auth/register`, `/auth/verify-email`, `/auth/login`, `/auth/apple`, `/auth/resend-code`, `/auth/refresh`, `GET /auth/me`, `POST /auth/forgot-password`, `POST /auth/reset-password`, `PUT /auth/change-password`, `PUT /auth/fcm-token`, `PUT /auth/notifications`, `DELETE /auth/account`
- **Products**: `GET /products/search/name`, `GET /products/:id`, `POST /products/search/image` (multipart), `POST /product-requests` (multipart)
- **Moderation**: `POST /moderation/products/:id` (multipart)
- **Popular**: `GET /popular`
- **Search History**: `GET /userprofile/search-history`, `POST /userprofile/search-history`, `DELETE /userprofile/search-history/:id`, `DELETE /userprofile/search-history`
- **Favorites**: `GET /userprofile/favorites`, `POST /userprofile/favorites`, `DELETE /userprofile/favorites/:id`, `POST /userprofile/favorites/toggle`, `GET /userprofile/favorites/:id/check`
- **Routines**: `GET /routines`, `GET /routines/my`, `GET /routines/favorites`, `GET /routines/user/:id`, `GET /routines/user/:id/favorites`, `GET /routines/:id`, `POST /routines`, `DELETE /routines/:id`, `POST /routines/:id/comments`, `POST /routines/:id/likes/toggle`, `POST /routines/upload-image` (multipart)
- **Profile**: `POST /userprofile/profile-image` (multipart), `PUT /userprofile`, `POST /userprofile/check-username`, `GET /userprofile`, `PUT /userprofile/bio`, `POST /userprofile/follow/:id`, `DELETE /userprofile/follow/:id`, `GET /userprofile/followers`, `GET /userprofile/following`, `GET /userprofile/search`, `GET /userprofile/public/:username`, `GET /userprofile/public/:username/followers`, `GET /userprofile/public/:username/following`, `GET /userprofile/public/:username/favorites`
- **Ingredients**: `GET /ingredients` (query, page, pageSize, minSafety, maxSafety, comedogenic, safetyLabel)

---

### ✅ ADIM 6 – Güvenli Token Depolama (`src/store/authStore.ts`)
`KeychainService` → `expo-secure-store`:
```ts
await SecureStore.setItemAsync('access_token', token);
await SecureStore.getItemAsync('access_token');
await SecureStore.deleteItemAsync('access_token');
```
Zustand store:
```ts
{ isAuthenticated, isInitializing, currentUser, needsUsername, login(), logout(), checkAuth(), register(), verifyEmail(), forgotPassword(), resetPassword(), setupUsername(), updateNotifications(), deleteAccount() }
```

---

### ✅ ADIM 7 – Root Layout & Auth Guard (`app/_layout.tsx`)
```
isInitializing → SplashScreen (animasyonlu logo)
isAuthenticated → MainTabs
  needsUsername → UsernameSetupScreen (modal)
  !isPremium → PaywallModal (launch'ta)
!isAuthenticated → LoginScreen
```

---

### ✅ ADIM 8 – Navigasyon (`app/(tabs)/_layout.tsx`)
5 sekme:
| Index | İkon | Ekran |
|---|---|---|
| 0 | home | HomeScreen |
| 1 | leaf | IngredientAnalysisScreen |
| 2 | scan | ScanScreen |
| 3 | people | SocialFeedScreen |
| 4 | person | ProfileScreen |
Aktif renk: `#D4728C`

---

### ✅ ADIM 9 – Auth Ekranları (`app/(auth)/`)

#### `login.tsx` – LoginView
- E-posta ile giriş formu
- **Apple Sign In** butonu (`expo-apple-authentication`)
- "Kayıt Ol" → RegisterScreen
- "Şifremi Unuttum" → ForgotPasswordScreen
- Login sonrası verify-email gerekiyorsa → VerifyEmailScreen

#### `register.tsx` – RegisterView
- Ad Soyad, E-posta, Şifre, Şifre Tekrar
- Submit → VerifyEmailScreen

#### `verify-email.tsx` – VerifyEmailView
- 6 haneli OTP giriş kutuları
- Countdown + "Kodu tekrar gönder"
- Doğrulama başarılı → ana uygulama

#### `forgot-password.tsx` – ForgotPasswordView
- E-posta gir → kod gönder

#### `reset-password.tsx` – ResetPasswordView
- 6 haneli kod + yeni şifre + şifre tekrar

#### `username-setup.tsx` – UsernameSetupView (modal)
- Kullanıcı adı gir
- Kullanılabilirlik kontrolü (debounce ile API)

---

### ADIM 10 – Home Ekranı (`app/(tabs)/index.tsx`) (TAMAMLANDI)

**HomeViewModel → Zustand + React hooks:**
- Arama çubuğu (debounce 350ms → `/products/search/name`)
- Arama sonuçları listesi (HomeProductRow)
- **Hero Card**: "Rafınızı Tarayın" → ScanScreen'e NavigationLink
- **En Çok Arananlar**: yatay kaydırılabilir PopularProductCard listesi
- **Hızlı Eylemler**: Quiz kartı (SkinTypeQuizModal) + Rutin Oluştur kartı
- **Son Aramalar**: HistoryRow listesi (silme + tümünü temizle)
- Ürüne tıklayınca → ProductDetailSheet (modal bottom sheet)

---

### ADIM 11 – Scan Ekranı (`app/(tabs)/scan.tsx` + bileşenler) (TAMAMLANDI)

Bu en büyük ekran (Swift'te 103KB). Aşamalı yapı:

**Durum makinesi:**
```
idle → capturing → analyzing → results → productDetail
```

**Alt adımlar:**
1. **Kamera bileşeni**: `expo-camera` ile tam ekran kamera, flaş toggle, galeri seçimi (`expo-image-picker`), overlay çerçeve
2. **OCR + görsel arama**: Çekilen resmi JPEG'e compress et, `multipart/form-data` ile `POST /products/search/image` (ocrText opsiyonel)
3. **Arama sonuçları ekranı**: Bulunan ürünler listesi, "Aradığınız değil mi?" → ProductRequestView
4. **Ürün detay ekranı** (ScanView içindeki büyük detail sayfası):
   - Ürün başlığı, marka, görseller (yatay scroll)
   - **Güvenlik skoru** (0–100 daire göstergesi)
   - **Güvenlik etiketi**: Güvenli & Temiz / Dikkatli Kullan / Yüksek Risk
   - **Cilt uyumluluğu** (premium lock): cildinize göre % uyum skoru
   - **İçerik listesi** (filtre: Tümü / Güvenli / Orta / Riskli)
   - Her içerik için IngredientRow: isim, ewg skoru, safety badge, iyi/kötü cilt listesi
   - Favorilere ekle / çıkar
   - **Moderasyon talebi** butonu → ModerationSheet
5. **ProductRequestView**: marka + ürün adı + fotoğraf (ön yüz + içerik) form
6. **Scan limiti**: Premium değil ve günlük 3 limit doldu → PaywallModal

---

### ADIM 12 – Ingredient Analysis Ekranı (`app/(tabs)/ingredients.tsx`)

- Hero banner (gradient arka plan)
- 6 kategori kartı: Tamamen Güvenli, Güvenli, Kabul Edilebilir, Orta, Riskli, Komedojenik
- Arama çubuğu → `GET /ingredients?search=&safetyLabel=&comedogenic=`
- Sonuç listesi (MatchedIngredient)
- Kategori filtreleme (safetyLevel 0–4, comedogenic bool)
- Her içerik tıklanınca → **IngredientDetailSheet**:
  - İsim, açıklama (TR/EN), EWG skoru
  - Safety badge
  - İyi gelecek / İyi gelmeyeceği cilt tipleri
  - AB/ABD kısıtlamaları
  - Safetymakeup linki

---

### ADIM 13 – Social Feed Ekranı (`app/(tabs)/social.tsx`)

**RoutineFeedView:**
- Arama çubuğu (rutinler + kişiler)
- **Sekmeler**: RUTINLER / KİŞİLER
- RUTINLER sekmesi:
  - `GET /routines?search=` listesi
  - RoutineFeedCard: kapak fotoğrafı, başlık, kullanıcı avatarı + adı, like/comment sayısı, beğeni toggle
  - Karta tıklama → RoutineDetailView (modalSheet)
- KİŞİLER sekmesi:
  - `GET /userprofile/search?query=` listesi
  - Her kullanıcı → UserProfileView (navigation push)
- "Rutin Oluştur" FAB butonu → RoutineCreateView
- Header sağ üst: Rutin oluştur ikonu

#### `RoutineDetailView` (modal/sheet)
- Kapak görseli
- Başlık, açıklama, yazar (tıklanınca UserProfileView)
- Ürün listesi (ProductRow → ProductDetailSheet)
- Yorumlar listesi
- Yorum yaz inputu
- Like toggle, yorum at

#### `RoutineCreateView`
- Sabah/Akşam tipi seçimi (toggle)
- Başlık, açıklama text input
- Fotoğraf ekle (expo-image-picker → upload `/routines/upload-image`)
- Ürün arama → `/products/search/name` → seçim listesi
- Seçilen ürünler (ekle/çıkar)
- Yayımla → `POST /routines`

---

### ADIM 14 – Profile Ekranı (`app/(tabs)/profile.tsx`)

**Kendi profili (ProfileView):**
- Avatar (fotoğraf değiştir: expo-image-picker → upload)
- İsim, @kullanıcı adı, bio
- Stats: Rutinler / Takipçi / Takip (tıklanınca ConnectionsView)
- Sekme: Rutinlerim | Favoriler
  - Rutinler: 3 sütun grid, tıkla → RoutineDetailView
  - Favoriler: alt sekme Ürünler | Rutinler, 3 sütun grid
- Toolbar: Profili Düzenle + Ayarlar

**EditProfileView (modal):**
- Ad Soyad, kullanıcı adı, bio güncelleme

**SettingsSheet (modal):**
- Şifremi Değiştir → ChangePasswordView
- Gizlilik Politikası → web link
- Dil seçimi (TR/EN)
- Çıkış Yap
- Hesabı Sil (confirmation alert)

**ChangePasswordView:** Mevcut + yeni şifre form

**SkinTypeQuizView (modal):**
- 7 sorulu quiz
- Progress bar
- Sonuç ekranı → cilt tipi hesaplama
- Backend'e kaydet → `PUT /userprofile`

**MyRoutinesView:** Profile içi rutin listesi

**UserProfileView (başkasının profili):**
- Takip Et / Takipten Çık butonu
- Profil header (public data)
- 3 sütun rutin grid
- Favoriler grid

**ConnectionsView:**
- Takipçiler veya Takip edilenler listesi
- Kendi profilm: `/followers`, `/following`
- Başkasının profili: `/public/:username/followers`, `/public/:username/following`

---

### ADIM 15 – Favorites Ekranı (ayrı sekme değil, Profile içi)
`GET /userprofile/favorites` → FavoriteResponse listesi  
Favori ürün → ProductDetailSheet  
Favori toggle → `POST /userprofile/favorites/toggle`

---

### ADIM 16 – Search History Ekranı
`GET /userprofile/search-history` (Home'da gösterilir)  
Ayrı tam ekran: `SearchHistoryView` (modal olarak açılabilir)  
Silme (tek tek + tümünü temizle)

---

### ADIM 17 – Paywall / Abonelik (`src/store/subscriptionStore.ts`)

**RevenueCat kullanımı:**
```ts
Purchases.configure({ apiKey: 'rc_...' });
// Paketler
const offerings = await Purchases.getOfferings();
// Satın al
await Purchases.purchasePackage(package);
// Restore
await Purchases.restorePurchases();
// Premium kontrolü 
const info = await Purchases.getCustomerInfo();
isPremium = info.entitlements.active['premium'] !== undefined;
```

**PaywallView:**
- Logo + başlık
- 3 özellik satırı (FeatureRow): Sınırsız Tarama, Cilt Uyumluluk Analizi, Reklamsız
- Yıllık / Aylık plan kartı (seçilebilir)
- Premium'a Geç butonu
- Satın almaları geri yükle
- Yasal metin

**Günlük tarama limiti:**
- `AsyncStorage`'da `scanCount_YYYY-MM-DD` key'i ile günlük tarama say
- 3 scan dolunca → PaywallModal göster

---

### ADIM 18 – Splash Screen
- `expo-splash-screen`: animasyonlu logo
- Logo pulse animasyonu (`react-native-reanimated` ile ölçek 0.97 ↔ 1.03)
- `checkAuth()` tamamlanınca splash'ı kaldır

---

## 3. Öncelik Sıralaması (Sprint Planı)

| Sprint | Konu | Açıklama |
|---|---|---|
| 1 | Altyapı | Kurulum, tema, i18n, tip tanımları, API katmanı, token depolama |
| 2 | Auth | Login, Register, VerifyEmail, ForgotPassword, ResetPassword, UsernameSetup |
| 3 | Home | Arama, PopularProducts, SearchHistory, QuickAction Cards |
| 4 | Scan (temel) | Kamera, galeri, görsel arama, sonuçlar listesi |
| 5 | Scan (detay) | ProductDetail sheet, ingredientler, güvenlik skoru, favori toggle |
| 6 | Ingredients | Kategori kartları, arama, IngredientDetail sheet |
| 7 | Social Feed | RoutineFeedCard, RoutineDetail, like/comment |
| 8 | Routine Create | Form, ürün arama, fotoğraf yükleme, yayımlama |
| 9 | Profile | Kendi/başkası profili, takip, edit, settings |
| 10 | Paywall | RevenueCat entegrasyonu, PaywallView, scan limiti |
| 11 | Polish | Animasyonlar, hata durumları, loading skeleton'lar, test |

---

## 4. Önemli Notlar

### API Base URL
```ts
export const API_BASE_URL = 'http://91.132.49.137:5192/api';
export const MEDIA_BASE_URL = 'http://91.132.49.137:5192';
```
Görsel URL'leri: `path.startsWith('http') ? path : MEDIA_BASE_URL + path`

### Çoklu Dil (i18n)
`expo-localization` ile cihaz dilini al, `tr` veya `en` seç.  
`SocialModels.swift` içindeki `L10nKey.tr` ve `L10nKey.en` değerleri direkt `tr.json` / `en.json`'a aktarılacak.  
200'den fazla anahtar var, tek seferde kopyalanmalı.

### Güvenlik Skoru Hesaplama
Swift'te `ScanView.swift` içinden (103KB dosya). Formül:
- Her içerik safety_level (0–4) toplanır
- Ağırlıklı ortalama → 0–100 skora normalize edilir
- Bu React Native'de aynı şekilde hesaplanacak

### Cilt Uyumluluğu
- Backend'den gelen `skin_compatibility.good_for[]` ve `bad_for[]` arrayleri
- Kullanıcının `skinType`'ı ile kesişim oranı → uyum skoru
- Premium feature: lock overlay göster, PaywallModal aç

### ProductImageUrl Dual Format
Backend bazen `"https://..."` string, bazen `{fileUrl: "...", fileName: "..."}` obje döner.  
```ts
function resolveImageUrl(item: any): string | undefined {
  if (typeof item === 'string') return item;
  return item?.fileUrl;
}
```

---

## 5. Paket.json Örneği (temel bağımlılıklar)

```json
{
  "dependencies": {
    "expo": "~52.0.0",
    "expo-router": "~4.0.0",
    "react-native": "0.76.0",
    "@react-navigation/native": "^7.0.0",
    "@react-navigation/bottom-tabs": "^7.0.0",
    "@react-navigation/native-stack": "^7.0.0",
    "zustand": "^5.0.0",
    "axios": "^1.7.0",
    "expo-secure-store": "~14.0.0",
    "expo-camera": "~16.0.0",
    "expo-image-picker": "~16.0.0",
    "expo-image": "~2.0.0",
    "expo-apple-authentication": "~7.0.0",
    "expo-localization": "~16.0.0",
    "expo-splash-screen": "~0.29.0",
    "react-native-reanimated": "~3.16.0",
    "react-native-gesture-handler": "~2.20.0",
    "react-native-screens": "~4.4.0",
    "react-native-safe-area-context": "4.12.0",
    "i18next": "^23.0.0",
    "react-i18next": "^15.0.0",
    "react-native-purchases": "^8.0.0",
    "lodash": "^4.17.21"
  }
}
```

---

## 6. Birebir Swift ↔ React Native Karşılaştırması

| Swift Dosya | React Native Karşılığı |
|---|---|
| `SkinCoreApp.swift` | `app/_layout.tsx` (RootLayout) |
| `MainTabView.swift` | `app/(tabs)/_layout.tsx` |
| `AuthViewModel.swift` | `src/store/authStore.ts` |
| `KeychainService.swift` | `expo-secure-store` utils |
| `APIClient.swift` | `src/api/apiClient.ts` |
| `SubscriptionService.swift` | `src/store/subscriptionStore.ts` + RevenueCat |
| `LanguageManager.swift` | `src/i18n/index.ts` + `useTranslation()` |
| `SocialModels.swift` (L10nKey) | `src/i18n/tr.json` + `en.json` |
| `AuthModels.swift` | `src/types/auth.ts` |
| `ProductModels.swift` | `src/types/product.ts` |
| `SocialModels.swift` (data models) | `src/types/social.ts` |
| `LoginView.swift` | `app/(auth)/login.tsx` |
| `RegisterView.swift` | `app/(auth)/register.tsx` |
| `VerifyEmailView.swift` | `app/(auth)/verify-email.tsx` |
| `ForgotPasswordView.swift` | `app/(auth)/forgot-password.tsx` |
| `ResetPasswordView.swift` | `app/(auth)/reset-password.tsx` |
| `HomeView.swift` | `app/(tabs)/index.tsx` |
| `ScanView.swift` | `app/(tabs)/scan.tsx` + alt bileşenler |
| `IngredientAnalysisView.swift` | `app/(tabs)/ingredients.tsx` |
| `SocialFeedView.swift` | `app/(tabs)/social.tsx` |
| `ProfileView.swift` | `app/(tabs)/profile.tsx` |
| `RoutineCreateView.swift` | `src/components/social/RoutineCreateView.tsx` |
| `RoutineDetailView.swift` | `src/components/social/RoutineDetailView.tsx` |
| `FavoritesView.swift` | Profile içi Favorites tab |
| `SearchHistoryView.swift` | Home içi Recent Searches veya modal |
| `PaywallView.swift` | `src/components/PaywallModal.tsx` |
| `EditProfileView.swift` | `src/components/profile/EditProfileModal.tsx` |
| `SkinTypeQuizView.swift` | `src/components/profile/SkinTypeQuizModal.tsx` |
| `ChangePasswordView.swift` | `src/components/profile/ChangePasswordModal.tsx` |
| `ProductRequestView.swift` | `src/components/scan/ProductRequestModal.tsx` |
| `MyRoutinesView.swift` | Profile içi Routines grid |

| `CachedImageView.swift` | `src/components/common/CachedImage.tsx` |
| `SplashView` (SkinCoreApp.swift) | Expo SplashScreen + custom animasyon |
