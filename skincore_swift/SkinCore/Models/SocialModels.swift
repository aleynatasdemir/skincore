import Foundation
import SwiftUI
import Combine

// MARK: - Language Manager

enum AppLanguage: String, CaseIterable {
    case tr, en
    var displayName: String { self == .tr ? "Türkçe" : "English" }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @Published private(set) var language: AppLanguage

    init() {
        let deviceCode = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "tr"
        language = AppLanguage(rawValue: deviceCode) ?? .tr
    }
    func s(_ key: L10nKey) -> String { key.string(language) }
}

// MARK: - L10n Keys

enum L10nKey {
    // MARK: General
    case appName
    case cancel, save, ok, confirm, loading, error

    // MARK: TabBar
    case tabHome, tabIngredients, tabScan, tabSocial, tabProfile

    // MARK: Auth - Common
    case email, password, fullName, username

    // MARK: Auth - Login
    case loginTitle, loginSubtitle
    case loginButton, loginContinueEmail
    case alreadyHaveAccount, newToSkincore, signUp
    case termsPrefix, termsOf, termService, termsAnd, termsPrivacy
    case startJourney

    // MARK: Auth - Register
    case createAccount, passwordMinChars, confirmPassword
    case passwordsNoMatch

    // MARK: Auth - Verify
    case verifyEmail, verifySubtitle, verifyButton, resendCode
    case passwordReset, passwordResetSuccess, loginAgain

    // MARK: Auth - Forgot Password
    case forgotPassword, forgotPasswordSubtitle, sendResetCode

    // MARK: Auth - Reset Password
    case resetPassword, resetCode, newPassword, confirmNewPassword
    case resetPasswordButton
    case passwordResetAlertTitle, resetCodeSentPrefix, verifyEmailSentPrefix
    
    // MARK: Auth - Change Password
    case changePasswordTitle, changePasswordCurrent, changePasswordNew, changePasswordConfirm, changePasswordSubmit, changePasswordSuccess

    // MARK: Auth - Username Setup
    case usernameTitle, usernameSubtitle, usernameAvailable, usernameTaken
    case usernameMinChars, usernamePlaceholder
    case continueButton, switchAccount

    // MARK: Profile Edit
    case fullNameLabel, bioLabel, editProfileTitle, editProfileSave, editProfileCancel

    // MARK: Home
    case homeSearchPlaceholder, homeMostSearched, homeSearchHistory
    case homeNoResults, homeSearchHint
    case homeProductNotFound, homeSubmit
    case homeScanBadge, homeScanTitle, homeScanDesc, homeScanNow
    case homeRecentSearches, homeClearAll, homeSearching, homeNoData
    case loginWelcome

    // MARK: Scan
    case scanTitle, scanSearching, scanFound, scanNotFound
    case scanTakePhoto, scanFlash, scanNotYourProduct
    case scanSubmitProduct, scanBrandName, scanProductName
    case scanFrontPhoto, scanIngredientsPhoto, scanSubmit
    case scanBrandRequired
    case scanAnalyzing, scanSearchingProducts, scanDBSearching, scanAnalyzeDone
    case scanTapProduct, scanTapProductDesc
    case scanCameraPermissionTitle, scanOpenSettings, scanCameraPermissionMsg
    case scanAlignHint, scanGallery
    case scanResultsTitle, scanProductNotFound, scanRetryPhoto, scanRetryPhotoDesc
    case scanBackToResults

    // MARK: Social
    case socialTitle, socialLoading, socialNoRoutines, socialBeFirst
    case socialPeople, socialRoutines, socialNoResults, socialDiffSearch
    case socialCreateRoutine, socialSearchPlaceholder

    // MARK: Routine Create / Detail
    case routineMorning, routineEvening
    case routineTitle, routineNamePlaceholder, routineDescPlaceholder
    case routinePhotoOptional, routineAddPhoto, routineShareJourney
    case routineSearchProduct, routineSearching, routineSearchResults
    case routineNoResults, routinePopularProducts
    case routineSelectedProducts, routineNoProducts, routineProductCount
    case routineAdd, routineRemove, routinePublish, routineLoading
    case routineProducts, routineComments, routineNoComments, routineLoadError
    case routineNavTitle, routineWriteComment

    // MARK: Profile
    case profileTitle, profileRoutines, profileFollowers, profileFollowing
    case profileFavorites, profileMyRoutines
    case profileNoRoutines, profileNoFavorites
    case profileSettings, profileLogout, profileEditBio
    case profileAccountSettings, profileNotifications, profilePrivacy
    case profileBio, profileEditBioTitle, profileBioSave
    case profileFollowersTitle, profileFollowingTitle
    case profileFollow, profileUnfollow
    case profileNobody, profileConnections
    case profileSearch, profileDefaultName, profileLanguage

    // MARK: Favorites
    case favTitle, favAllProducts, favNoFavorites, favNoFavoritesSubtitle, favRemove
    case favoriteProductsTitle, favoriteRoutinesTitle

    // MARK: My Routines
    case myRoutinesTitle, myRoutinesEmpty, myRoutinesProductCount

    // MARK: Product Request
    case productRequestTitle, productRequestSubtitle
    case productRequestBrandPlaceholder, productRequestProductPlaceholder
    case productRequestFrontTitle, productRequestFrontSubtitle
    case productRequestIngredientsTitle, productRequestIngredientsSubtitle
    case productRequestSelectPhoto, productRequestSubmit
    case productRequestAlertTitle, productRequestAlertMsg

    // MARK: Search History
    case historyTitle, historyClearAll, historyEmpty, historyEmptySubtitle

    // MARK: Social Feed Labels
    case socialCoreProducts, socialProductsUsed

    // MARK: Ingredients
    case ingredientsTitle, ingredientsSearch, ingredientsNoResults
    case ingredientsHeroBanner, ingredientsCatHeader, ingredientsCatSubtitle, ingredientsSearchPlaceholder
    case ingredientCatCompletelySafe, ingredientCatCompletelySafeDesc
    case ingredientCatSafe, ingredientCatSafeDesc
    case ingredientCatAcceptable, ingredientCatAcceptableDesc
    case ingredientCatModerate, ingredientCatModerateDesc
    case ingredientCatRisky, ingredientCatRiskyDesc
    case ingredientCatComedogenic, ingredientCatComedogenicDesc

    // MARK: Ingredient Detail
    case ingredientSafeSection, ingredientCategorySubtitle
    case ingredientNoData, ingredientAnalysisResult, ingredientFoundCount
    case ingredientLowRisk, ingredientModerateRisk, ingredientHighRisk
    case ingredientGoodFor, ingredientBadFor, ingredientEwgScore

    // MARK: Badges
    case badgeClean, badgeSafe, badgeAlert

    // MARK: Product Fallbacks
    case productDefault, productUnnamed, productIngredientCount, searchProductsFound

    // MARK: Scan - Product Detail
    case scanSafetyClean, scanSafetyCaution, scanSafetyHighRisk
    case scanSafetyCleanDesc, scanSafetyCautionDesc, scanSafetyHighRiskDesc
    case scanVeganClean, scanOverallScore, scanScoreOutOf
    case scanIngredientsList, scanFilterButton, scanNoIngredientsInCategory

    // MARK: Scan - Filter Pills
    case filterAll, filterSafe, filterModerate, filterRisky

    // MARK: Scan - Ingredient Detail Badge
    case ingredientBadgeSafe, ingredientBadgeModerate, ingredientBadgeAvoid, ingredientBadgeUnknown

    // MARK: Misc
    case appBrand, ewgScoreLabel
    case matchesFound, noProductsForQuery, nearestMatch, analyzing
    case ewgScore, restrictedRegion
    case placeholderFavorites, placeholderFavoritesDesc, placeholderProfile, placeholderComingSoon

    func string(_ lang: AppLanguage) -> String {
        switch lang {
        case .tr: return tr
        case .en: return en
        }
    }

    var tr: String {
        switch self {
        case .appName: return "skincore."
        case .cancel: return "İptal"
        case .save: return "Kaydet"
        case .ok: return "Tamam"
        case .confirm: return "Onayla"
        case .loading: return "Yükleniyor..."
        case .error: return "Hata"

        case .tabHome: return "Anasayfa"
        case .tabIngredients: return "İçerikler"
        case .tabScan: return "Tara"
        case .tabSocial: return "Sosyal"
        case .tabProfile: return "Profil"

        case .email: return "E-posta"
        case .password: return "Şifre"
        case .fullName: return "Ad Soyad"
        case .username: return "Kullanıcı Adı"

        case .loginTitle: return "Tekrar Hoş Geldin"
        case .loginSubtitle: return "Bilime dayalı cilt bakımı burada başlar.\nEn iyi cildin için içerikleri analiz et."
        case .loginButton: return "Giriş Yap"
        case .loginContinueEmail: return "E-posta ile Devam Et"
        case .alreadyHaveAccount: return "Zaten hesabın var mı?"
        case .newToSkincore: return "Skincore'a yeni misin?"
        case .signUp: return "Kayıt Ol"
        case .termsPrefix: return "Devam ederek Skincore'un "
        case .termsOf: return "Kullanım"
        case .termService: return "Koşulları"
        case .termsAnd: return " ve "
        case .termsPrivacy: return "Gizlilik Politikasını"
        case .startJourney: return "Cilt bakımı yolculuğuna başla"

        case .createAccount: return "Hesap Oluştur"
        case .passwordMinChars: return "Şifre (min 8 karakter)"
        case .confirmPassword: return "Şifre Tekrar"
        case .passwordsNoMatch: return "Şifreler eşleşmiyor"

        case .verifyEmail: return "E-postanı Doğrula"
        case .verifySubtitle: return "Gönderilen 6 haneli kodu gir"
        case .verifyButton: return "Doğrula"
        case .resendCode: return "Kodu tekrar gönder"
        case .passwordReset: return "Şifremi Unuttum"
        case .passwordResetSuccess: return "Şifren başarıyla sıfırlandı."
        case .loginAgain: return "Yeni şifrenle giriş yapabilirsin."

        case .forgotPassword: return "Şifremi Unuttum"
        case .forgotPasswordSubtitle: return "E-posta adresini gir, sana 6 haneli sıfırlama kodu gönderelim."
        case .sendResetCode: return "Sıfırlama Kodu Gönder"

        case .resetPassword: return "Şifreyi Sıfırla"
        case .resetCode: return "6 haneli kod"
        case .newPassword: return "Yeni Şifre"
        case .confirmNewPassword: return "Yeni Şifre Tekrar"
        case .resetPasswordButton: return "Şifreyi Sıfırla"
        case .passwordResetAlertTitle: return "Şifre Sıfırlandı"
        case .resetCodeSentPrefix: return "Gönderilen 6 haneli kodu gir"
        case .verifyEmailSentPrefix: return "Gönderilen 6 haneli kodu gir"

        case .changePasswordTitle: return "Şifreni Değiştir"
        case .changePasswordCurrent: return "Mevcut Şifre"
        case .changePasswordNew: return "Yeni Şifre"
        case .changePasswordConfirm: return "Yeni Şifre Tekrar"
        case .changePasswordSubmit: return "Onayla"
        case .changePasswordSuccess: return "Şifren başarıyla değiştirildi."

        case .usernameTitle: return "Kullanıcı Adın"
        case .usernameSubtitle: return "Topluluğa katılmak için bir kullanıcı adı seç.\nDaha sonra değiştirebilirsin."
        case .usernameAvailable: return " kullanılabilir"
        case .usernameTaken: return "Bu kullanıcı adı alınmış"
        case .usernameMinChars: return "En az 3 karakter olmalı"
        case .usernamePlaceholder: return "kullaniciadi"
        case .continueButton: return "Devam Et"
        case .switchAccount: return "Farklı hesapla giriş yap"

        case .homeSearchPlaceholder: return "Ürün veya içerik ara..."
        case .homeMostSearched: return "En Çok Arananlar"
        case .homeSearchHistory: return "Arama Geçmişi"
        case .homeNoResults: return "Sonuç bulunamadı"
        case .homeSearchHint: return "Farklı bir arama dene"
        case .homeProductNotFound: return "Ürün bulunamadı mı?"
        case .homeSubmit: return "Bize gönder"
        case .homeScanBadge: return "YENİ ÖZELLİK"
        case .homeScanTitle: return "Rafınızı Tarayın"
        case .homeScanDesc: return "Tüm içerikleri anında analiz edin ve\ngüvenlik puanlarını kontrol edin."
        case .homeScanNow: return "Şimdi Tara"
        case .homeRecentSearches: return "Son Aramalar"
        case .homeClearAll: return "Tümünü Temizle"
        case .homeSearching: return "Aranıyor…"
        case .homeNoData: return "Henüz veri yok"
        case .loginWelcome: return "Skincore'a Hoş Geldiniz"

        case .scanTitle: return "Tara"
        case .scanSearching: return "Analiz ediliyor..."
        case .scanFound: return "Ürün Bulundu"
        case .scanNotFound: return "Ürün Bulunamadı"
        case .scanTakePhoto: return "Fotoğraf Çek"
        case .scanFlash: return "Flaş"
        case .scanNotYourProduct: return "Aradığınız ürün bunlar değil mi?"
        case .scanSubmitProduct: return "Ürün Gönder"
        case .scanBrandName: return "Marka Adı"
        case .scanProductName: return "Ürün Adı (isteğe bağlı)"
        case .scanFrontPhoto: return "Ön Fotoğraf"
        case .scanIngredientsPhoto: return "İçerik Fotoğrafı"
        case .scanSubmit: return "Gönder"
        case .scanBrandRequired: return "Marka adı zorunlu"
        case .scanAnalyzing: return "Analiz ediliyor…"
        case .scanSearchingProducts: return "Ürünler aranıyor…"
        case .scanDBSearching: return "Ürün veritabanında en yakın eşleşmeler aranıyor"
        case .scanAnalyzeDone: return "Analiz tamamlandı"
        case .scanTapProduct: return "Ürünü Tara"
        case .scanTapProductDesc: return "Etiketi çek, içerikler analiz edilsin"
        case .scanCameraPermissionTitle: return "Kamera İzni Gerekli"
        case .scanOpenSettings: return "Ayarları Aç"
        case .scanCameraPermissionMsg: return "Ürün taramak için kamera iznine ihtiyaç var."
        case .scanAlignHint: return "Ürünü çerçeve içine hizala"
        case .scanGallery: return "GALERİ"
        case .scanResultsTitle: return "ARAMA SONUÇLARI"
        case .scanProductNotFound: return "Ürün bulunamadı"
        case .scanRetryPhoto: return "Tekrar Çek"
        case .scanRetryPhotoDesc: return "Etiketi daha yakından çekip tekrar dene"
        case .scanBackToResults: return "Sonuçlar"

        case .socialTitle: return "Skincore"
        case .socialLoading: return "Yükleniyor..."
        case .socialNoRoutines: return "Henüz paylaşılmış rutin yok"
        case .socialBeFirst: return "İlk rutini sen paylaş"
        case .socialPeople: return "KİŞİLER"
        case .socialRoutines: return "RUTİNLER"
        case .socialNoResults: return "Sonuç bulunamadı"
        case .socialDiffSearch: return "Farklı bir arama dene"
        case .socialCreateRoutine: return "Rutin Oluştur"
        case .socialSearchPlaceholder: return "Rutin ya da kullanıcı ara"

        case .routineMorning: return "Sabah Rutini"
        case .routineEvening: return "Akşam Rutini"
        case .routineTitle: return "Rutin Oluştur"
        case .routineNamePlaceholder: return "Rutin başlığı"
        case .routineDescPlaceholder: return "Kısa bir açıklama yaz"
        case .routinePhotoOptional: return "FOTOĞRAF (OPSİYONEL)"
        case .routineAddPhoto: return "Rutinine bir fotoğraf ekle"
        case .routineShareJourney: return "Cildinin değişimini paylaş"
        case .routineSearchProduct: return "Ürün ara..."
        case .routineSearching: return "Aranıyor..."
        case .routineSearchResults: return "Arama Sonuçları"
        case .routineNoResults: return "Sonuç bulunamadı"
        case .routinePopularProducts: return "Popüler Ürünler"
        case .routineSelectedProducts: return "Seçilen Ürünler"
        case .routineNoProducts: return "Henüz ürün seçilmedi"
        case .routineProductCount: return "ürün"
        case .routineAdd: return "Ekle"
        case .routineRemove: return "Çıkar"
        case .routinePublish: return "Yayımla"
        case .routineLoading: return "Yükleniyor..."
        case .routineProducts: return "Ürünler"
        case .routineComments: return "Yorumlar"
        case .routineNoComments: return "Henüz yorum yok"
        case .routineLoadError: return "Rutin yüklenemedi"
        case .routineNavTitle: return "Rutin"
        case .routineWriteComment: return "Yorum yaz..."

        case .profileTitle: return "My Skincore"
        case .profileRoutines: return "Rutinler"
        case .profileFollowers: return "Takipçi"
        case .profileFollowing: return "Takip"
        case .profileFavorites: return "Favoriler"
        case .profileMyRoutines: return "Rutinlerim"
        case .profileNoRoutines: return "Henüz rutin yok"
        case .profileNoFavorites: return "Henüz favori yok"
        case .profileSettings: return "Ayarlar"
        case .profileLogout: return "Çıkış Yap"
        case .profileEditBio: return "Biyografiyi Düzenle"
        case .profileAccountSettings: return "Hesap Ayarları"
        case .profileNotifications: return "Bildirimler"
        case .profilePrivacy: return "Gizlilik"
        case .profileBio: return "Biyografi"
        case .profileEditBioTitle: return "Biyografi Düzenle"
        case .profileBioSave: return "Kaydet"
        case .profileFollowersTitle: return "Takipçiler"
        case .profileFollowingTitle: return "Takip Edilenler"
        case .profileFollow: return "Takip Et"
        case .profileUnfollow: return "Takipten Çık"
        case .profileNobody: return "Henüz kimse yok"
        case .profileConnections: return "Bağlantılar"
        case .profileSearch: return "Ara..."
        case .profileDefaultName: return "Kullanıcı"
        case .profileLanguage: return "Dil"

        case .favTitle: return "Favorilerim"
        case .favAllProducts: return "Tüm Ürünler"
        case .favNoFavorites: return "Henüz favori yok"
        case .favNoFavoritesSubtitle: return "Favori ürünleriniz burada görünecek"
        case .favRemove: return "Kaldır"
        case .favoriteProductsTitle: return "Favori Ürünlerim"
        case .favoriteRoutinesTitle: return "Favori Rutinlerim"

        case .myRoutinesTitle: return "Rutinlerim"
        case .myRoutinesEmpty: return "Henüz bir rutin oluşturmadın"
        case .myRoutinesProductCount: return "Ürün"

        case .productRequestTitle: return "Ürün Talebi"
        case .productRequestSubtitle: return "Aradığınız ürünü veritabanımıza ekleyebilmemiz için\nbilgileri doldurun."
        case .productRequestBrandPlaceholder: return "Marka Adı (zorunlu)"
        case .productRequestProductPlaceholder: return "Ürün Adı (opsiyonel)"
        case .productRequestFrontTitle: return "Ürünün Ön Yüzü"
        case .productRequestFrontSubtitle: return "Marka ve ürün adının göründüğü taraf"
        case .productRequestIngredientsTitle: return "İçerik Listesi"
        case .productRequestIngredientsSubtitle: return "Ingredients / İçindekiler kısmı"
        case .productRequestSelectPhoto: return "Fotoğraf Seç"
        case .productRequestSubmit: return "Talebi Gönder"
        case .productRequestAlertTitle: return "Talebiniz Alındı!"
        case .productRequestAlertMsg: return "Ürünü en kısa sürede inceleyip veritabanına ekleyeceğiz."

        case .historyTitle: return "Arama Geçmişi"
        case .historyClearAll: return "Tümünü Temizle"
        case .historyEmpty: return "Henüz arama geçmişi yok"
        case .historyEmptySubtitle: return "Ürün aradığınızda burada görünecek"

        case .socialCoreProducts: return "Favori Ürünlerim"
        case .socialProductsUsed: return "KULLANILAN ÜRÜNLER"

        case .ingredientsTitle: return "İçerik Analizi"
        case .ingredientsSearch: return "İçerik ara..."
        case .ingredientsNoResults: return "Sonuç bulunamadı"
        case .ingredientsHeroBanner: return "İçinde ne olduğunu keşfet,\ncildini koru."
        case .ingredientsCatHeader: return "İçerik Kategorileri"
        case .ingredientsCatSubtitle: return "Ürünlerinizin güvenlik profilini anlayın"
        case .ingredientsSearchPlaceholder: return "İçerik ara (ör. Retinol)"
        case .ingredientCatCompletelySafe: return "Tamamen Güvenli"
        case .ingredientCatCompletelySafeDesc: return "Hassas ciltler için bile bilinen risk veya tahriş edici içermeyen bileşenler."
        case .ingredientCatSafe: return "Güvenli"
        case .ingredientCatSafeDesc: return "Çoğu cilt tipi için güvenli kabul edilen, yaygın kullanılan bileşenler."
        case .ingredientCatAcceptable: return "Kabul Edilebilir"
        case .ingredientCatAcceptableDesc: return "Genel olarak güvenli ancak nadir durumlarda hafif reaksiyona yol açabilir."
        case .ingredientCatModerate: return "Orta Düzey Güvenlik"
        case .ingredientCatModerateDesc: return "Tahriş potansiyeli var. Bariyer hasarı olanlarda dikkatli kullanın."
        case .ingredientCatRisky: return "Riskli"
        case .ingredientCatRiskyDesc: return "Yüksek tahriş veya zarar riski. Kullanmayın veya çok dikkatli kullanın."
        case .ingredientCatComedogenic: return "Komedojenisite"
        case .ingredientCatComedogenicDesc: return "Bileşenin gözenekleri tıkayıp sivilceye yol açma olasılığı."

        case .ingredientSafeSection: return "GÜVENLİ İÇERİKLER"
        case .ingredientCategorySubtitle: return "Bu kategorideki tüm bileşenler"
        case .ingredientNoData: return "İçerik bulunamadı"
        case .ingredientAnalysisResult: return "ANALİZ SONUCU"
        case .ingredientFoundCount: return "İçerik Bulundu"
        case .ingredientLowRisk: return "Düşük Risk"
        case .ingredientModerateRisk: return "Orta Risk"
        case .ingredientHighRisk: return "Yüksek Risk"
        case .ingredientGoodFor: return "İYİ GELECEK"
        case .ingredientBadFor: return "İYİ GELMEYECEĞİ"
        case .ingredientEwgScore: return "EWG SKORU"

        case .badgeClean: return "TEMİZ"
        case .badgeSafe: return "GÜVENLİ"
        case .badgeAlert: return "DİKKAT"

        case .productDefault: return "Ürün"
        case .productUnnamed: return "İsimsiz Ürün"
        case .productIngredientCount: return "İçerik"
        case .searchProductsFound: return "ürün bulundu"

        case .scanSafetyClean: return "Güvenli & Temiz"
        case .scanSafetyCaution: return "Dikkatli Kullan"
        case .scanSafetyHighRisk: return "Yüksek Risk"
        case .scanSafetyCleanDesc: return "Bu ürün, tahriş veya toksisite riski düşük kaliteli içerikler barındırıyor."
        case .scanSafetyCautionDesc: return "Bu ürün, hassas cilt tipleri için hafif tahriş yapabilecek bazı içerikler içeriyor."
        case .scanSafetyHighRiskDesc: return "Bu ürün zararlı olabilecek içerikler barındırıyor. Alternatif ürünleri değerlendirmenizi öneririz."
        case .scanVeganClean: return "Vegan & Temiz"
        case .scanOverallScore: return "GENEL GÜVENLİK SKORU"
        case .scanScoreOutOf: return "100 üzerinden"
        case .scanIngredientsList: return "İçerikler"
        case .scanFilterButton: return "Filtrele"
        case .scanNoIngredientsInCategory: return "Bu kategoride içerik yok"

        case .filterAll: return "Tümü"
        case .filterSafe: return "Güvenli"
        case .filterModerate: return "Orta"
        case .filterRisky: return "Riskli"

        case .ingredientBadgeSafe: return "GÜVENLİ"
        case .ingredientBadgeModerate: return "ORTA"
        case .ingredientBadgeAvoid: return "KAÇIN"
        case .ingredientBadgeUnknown: return "BİLİNMİYOR"

        case .appBrand: return "skincore."
        case .ewgScoreLabel: return "EWG Skoru:"
        case .matchesFound: return "eşleşme bulundu"
        case .noProductsForQuery: return "için ürün bulunamadı"
        case .nearestMatch: return "en yakın eşleşme"
        case .analyzing: return "Analiz ediliyor…"
        case .ewgScore: return "EWG Skoru"
        case .restrictedRegion: return "'de kısıtlı / potansiyel uyarı"
        case .placeholderFavorites: return "Favoriler"
        case .placeholderFavoritesDesc: return "Kaydedilmiş ürünleriniz"
        case .placeholderProfile: return "Profil"
        case .placeholderComingSoon: return "Çok Yakında"

        case .fullNameLabel: return "Ad Soyad"
        case .bioLabel: return "Biyografi"
        case .editProfileTitle: return "Profili Düzenle"
        case .editProfileSave: return "Ayarla"
        case .editProfileCancel: return "İptal"
        }
    }

    var en: String {
        switch self {
        case .appName: return "skincore."
        case .cancel: return "Cancel"
        case .save: return "Save"
        case .ok: return "OK"
        case .confirm: return "Confirm"
        case .loading: return "Loading..."
        case .error: return "Error"

        case .tabHome: return "Home"
        case .tabIngredients: return "Ingredients"
        case .tabScan: return "Scan"
        case .tabSocial: return "Social"
        case .tabProfile: return "Profile"

        case .email: return "Email"
        case .password: return "Password"
        case .fullName: return "Full Name"
        case .username: return "Username"

        case .loginTitle: return "Welcome Back"
        case .loginSubtitle: return "Science-backed skincare starts here.\nAnalyze ingredients for your best skin ever."
        case .loginButton: return "Log In"
        case .loginContinueEmail: return "Continue with Email"
        case .alreadyHaveAccount: return "Already have an account?"
        case .newToSkincore: return "New to Skincore?"
        case .signUp: return "Sign Up"
        case .termsPrefix: return "By continuing, you agree to Skincore's "
        case .termsOf: return "Terms of"
        case .termService: return "Service"
        case .termsAnd: return " and "
        case .termsPrivacy: return "Privacy Policy"
        case .startJourney: return "Start your skincare journey"

        case .createAccount: return "Create Account"
        case .passwordMinChars: return "Password (min 8 chars)"
        case .confirmPassword: return "Confirm Password"
        case .passwordsNoMatch: return "Passwords do not match"

        case .verifyEmail: return "Verify Email"
        case .verifySubtitle: return "Enter the 6-digit code we sent you"
        case .verifyButton: return "Verify"
        case .resendCode: return "Resend code"
        case .passwordReset: return "Forgot Password"
        case .passwordResetSuccess: return "Your password has been reset."
        case .loginAgain: return "Please log in with your new password."

        case .forgotPassword: return "Forgot Password"
        case .forgotPasswordSubtitle: return "Enter your email address and we'll send you a 6-digit reset code."
        case .sendResetCode: return "Send Reset Code"

        case .resetPassword: return "Reset Password"
        case .resetCode: return "6-digit code"
        case .newPassword: return "New Password"
        case .confirmNewPassword: return "Confirm New Password"
        case .resetPasswordButton: return "Reset Password"
        case .passwordResetAlertTitle: return "Password Reset Successful"
        case .resetCodeSentPrefix: return "Enter the 6-digit code sent to"
        case .verifyEmailSentPrefix: return "We sent a 6-digit code to"

        case .changePasswordTitle: return "Change Your Password"
        case .changePasswordCurrent: return "Current Password"
        case .changePasswordNew: return "New Password"
        case .changePasswordConfirm: return "Confirm New Password"
        case .changePasswordSubmit: return "Confirm"
        case .changePasswordSuccess: return "Your password has been changed successfully."

        case .usernameTitle: return "Your Username"
        case .usernameSubtitle: return "Choose a username to join the community.\nYou can change it later."
        case .usernameAvailable: return " is available"
        case .usernameTaken: return "This username is taken"
        case .usernameMinChars: return "At least 3 characters required"
        case .usernamePlaceholder: return "username"
        case .continueButton: return "Continue"
        case .switchAccount: return "Sign in with a different account"

        case .homeSearchPlaceholder: return "Search products or ingredients..."
        case .homeMostSearched: return "Most Searched"
        case .homeSearchHistory: return "Search History"
        case .homeNoResults: return "No results found"
        case .homeSearchHint: return "Try a different search"
        case .homeProductNotFound: return "Can't find your product?"
        case .homeSubmit: return "Send it to us"
        case .homeScanBadge: return "NEW FEATURE"
        case .homeScanTitle: return "Scan Your Shelf"
        case .homeScanDesc: return "Instantly analyze all ingredients and\ncheck safety ratings."
        case .homeScanNow: return "Scan Now"
        case .homeRecentSearches: return "Recent Searches"
        case .homeClearAll: return "Clear All"
        case .homeSearching: return "Searching…"
        case .homeNoData: return "No data yet"
        case .loginWelcome: return "Welcome to Skincore"

        case .scanTitle: return "Scan"
        case .scanSearching: return "Analyzing..."
        case .scanFound: return "Product Found"
        case .scanNotFound: return "Product Not Found"
        case .scanTakePhoto: return "Take Photo"
        case .scanFlash: return "Flash"
        case .scanNotYourProduct: return "Not what you were looking for?"
        case .scanSubmitProduct: return "Submit Product"
        case .scanBrandName: return "Brand Name"
        case .scanProductName: return "Product Name (optional)"
        case .scanFrontPhoto: return "Front Photo"
        case .scanIngredientsPhoto: return "Ingredients Photo"
        case .scanSubmit: return "Submit"
        case .scanBrandRequired: return "Brand name is required"
        case .scanAnalyzing: return "Analyzing…"
        case .scanSearchingProducts: return "Searching products…"
        case .scanDBSearching: return "Looking for the closest matches in the database"
        case .scanAnalyzeDone: return "Analysis complete"
        case .scanTapProduct: return "Scan Product"
        case .scanTapProductDesc: return "Take a photo of the label to analyze ingredients"
        case .scanCameraPermissionTitle: return "Camera Access Required"
        case .scanOpenSettings: return "Open Settings"
        case .scanCameraPermissionMsg: return "Camera access is needed to scan products."
        case .scanAlignHint: return "Align the product within the frame"
        case .scanGallery: return "GALLERY"
        case .scanResultsTitle: return "SEARCH RESULTS"
        case .scanProductNotFound: return "No product found"
        case .scanRetryPhoto: return "Try Again"
        case .scanRetryPhotoDesc: return "Take a closer photo of the label and try again"
        case .scanBackToResults: return "Results"

        case .socialTitle: return "Skincore"
        case .socialLoading: return "Loading..."
        case .socialNoRoutines: return "No routines shared yet"
        case .socialBeFirst: return "Be the first to share a routine"
        case .socialPeople: return "PEOPLE"
        case .socialRoutines: return "ROUTINES"
        case .socialNoResults: return "No results found"
        case .socialDiffSearch: return "Try a different search"
        case .socialCreateRoutine: return "Create Routine"
        case .socialSearchPlaceholder: return "Search routines or people"

        case .routineMorning: return "Morning Routine"
        case .routineEvening: return "Evening Routine"
        case .routineTitle: return "Create Routine"
        case .routineNamePlaceholder: return "Routine title"
        case .routineDescPlaceholder: return "Write a brief description"
        case .routinePhotoOptional: return "PHOTO (OPTIONAL)"
        case .routineAddPhoto: return "Add a photo to your routine"
        case .routineShareJourney: return "Share your skin journey"
        case .routineSearchProduct: return "Search product..."
        case .routineSearching: return "Searching..."
        case .routineSearchResults: return "Search Results"
        case .routineNoResults: return "No results found"
        case .routinePopularProducts: return "Popular Products"
        case .routineSelectedProducts: return "Selected Products"
        case .routineNoProducts: return "No products selected yet"
        case .routineProductCount: return "products"
        case .routineAdd: return "Add"
        case .routineRemove: return "Remove"
        case .routinePublish: return "Publish"
        case .routineLoading: return "Loading..."
        case .routineProducts: return "Products"
        case .routineComments: return "Comments"
        case .routineNoComments: return "No comments yet"
        case .routineLoadError: return "Could not load routine"
        case .routineNavTitle: return "Routine"
        case .routineWriteComment: return "Write a comment..."

        case .profileTitle: return "My Skincore"
        case .profileRoutines: return "Routines"
        case .profileFollowers: return "Followers"
        case .profileFollowing: return "Following"
        case .profileFavorites: return "Favorites"
        case .profileMyRoutines: return "My Routines"
        case .profileNoRoutines: return "No routines yet"
        case .profileNoFavorites: return "No favorites yet"
        case .profileSettings: return "Settings"
        case .profileLogout: return "Log Out"
        case .profileEditBio: return "Edit Bio"
        case .profileAccountSettings: return "Account Settings"
        case .profileNotifications: return "Notifications"
        case .profilePrivacy: return "Privacy"
        case .profileBio: return "Bio"
        case .profileEditBioTitle: return "Edit Bio"
        case .profileBioSave: return "Save"
        case .profileFollowersTitle: return "Followers"
        case .profileFollowingTitle: return "Following"
        case .profileFollow: return "Follow"
        case .profileUnfollow: return "Unfollow"
        case .profileNobody: return "Nobody here yet"
        case .profileConnections: return "Connections"
        case .profileSearch: return "Search..."
        case .profileDefaultName: return "User"
        case .profileLanguage: return "Language"

        case .fullNameLabel: return "Full Name"
        case .bioLabel: return "Bio"
        case .editProfileTitle: return "Edit Profile"
        case .editProfileSave: return "Save"
        case .editProfileCancel: return "Cancel"

        case .favTitle: return "My Favorites"
        case .favAllProducts: return "All Products"
        case .favNoFavorites: return "No favorites yet"
        case .favNoFavoritesSubtitle: return "Products you favorite will appear here"
        case .favRemove: return "Remove"
        case .favoriteProductsTitle: return "My Favorite Products"
        case .favoriteRoutinesTitle: return "My Favorite Routines"

        case .myRoutinesTitle: return "My Routines"
        case .myRoutinesEmpty: return "No routines yet"
        case .myRoutinesProductCount: return "Product"

        case .productRequestTitle: return "Product Request"
        case .productRequestSubtitle: return "Fill in the details to help us add\nthe product to our database."
        case .productRequestBrandPlaceholder: return "Brand Name (required)"
        case .productRequestProductPlaceholder: return "Product Name (optional)"
        case .productRequestFrontTitle: return "Product Front"
        case .productRequestFrontSubtitle: return "Side showing brand and product name"
        case .productRequestIngredientsTitle: return "Ingredients List"
        case .productRequestIngredientsSubtitle: return "Ingredients / contents section"
        case .productRequestSelectPhoto: return "Select Photo"
        case .productRequestSubmit: return "Submit Request"
        case .productRequestAlertTitle: return "Request Received!"
        case .productRequestAlertMsg: return "We'll review the product and add it to our database soon."

        case .historyTitle: return "Search History"
        case .historyClearAll: return "Clear All"
        case .historyEmpty: return "No search history yet"
        case .historyEmptySubtitle: return "Products you search will appear here"

        case .socialCoreProducts: return "CORE PRODUCTS"
        case .socialProductsUsed: return "PRODUCTS USED"

        case .ingredientsTitle: return "Ingredient Analysis"
        case .ingredientsSearch: return "Search ingredients..."
        case .ingredientsNoResults: return "No results found"
        case .ingredientsHeroBanner: return "Discover what's inside,\nprotect your skin."
        case .ingredientsCatHeader: return "Ingredient Categories"
        case .ingredientsCatSubtitle: return "Understand the safety profile of your products"
        case .ingredientsSearchPlaceholder: return "Search ingredients (e.g. Retinol)"
        case .ingredientCatCompletelySafe: return "Completely Safe"
        case .ingredientCatCompletelySafeDesc: return "Ingredients with no known risks or irritants even for sensitive skin."
        case .ingredientCatSafe: return "Safe"
        case .ingredientCatSafeDesc: return "Widely used ingredients considered safe for most skin types."
        case .ingredientCatAcceptable: return "Acceptable"
        case .ingredientCatAcceptableDesc: return "Generally safe but may cause mild reaction in rare cases."
        case .ingredientCatModerate: return "Moderate Safety"
        case .ingredientCatModerateDesc: return "Potential for irritation. Use with caution on compromised barriers."
        case .ingredientCatRisky: return "Risky"
        case .ingredientCatRiskyDesc: return "High risk of irritation or harm. Avoid or use with extreme caution."
        case .ingredientCatComedogenic: return "Comedogenicity"
        case .ingredientCatComedogenicDesc: return "Likelihood of the ingredient to clog pores and cause breakouts."

        case .ingredientSafeSection: return "SAFE INGREDIENTS"
        case .ingredientCategorySubtitle: return "All components in this category"
        case .ingredientNoData: return "No ingredients found"
        case .ingredientAnalysisResult: return "ANALYSIS RESULT"
        case .ingredientFoundCount: return "Ingredients Found"
        case .ingredientLowRisk: return "Low Risk"
        case .ingredientModerateRisk: return "Moderate Risk"
        case .ingredientHighRisk: return "High Risk"
        case .ingredientGoodFor: return "GOOD FOR"
        case .ingredientBadFor: return "BAD FOR"
        case .ingredientEwgScore: return "EWG SCORE"

        case .badgeClean: return "CLEAN"
        case .badgeSafe: return "SAFE"
        case .badgeAlert: return "ALERT"

        case .productDefault: return "Product"
        case .productUnnamed: return "Unnamed Product"
        case .productIngredientCount: return "Ingredients"
        case .searchProductsFound: return "products found"

        case .scanSafetyClean: return "Safe & Clean"
        case .scanSafetyCaution: return "Use with Caution"
        case .scanSafetyHighRisk: return "High Risk"
        case .scanSafetyCleanDesc: return "This product contains low-risk ingredients with minimal irritation or toxicity concerns."
        case .scanSafetyCautionDesc: return "This product contains some ingredients that may cause mild irritation for sensitive skin types."
        case .scanSafetyHighRiskDesc: return "This product contains potentially harmful ingredients. We recommend exploring alternative products."
        case .scanVeganClean: return "Vegan & Clean"
        case .scanOverallScore: return "OVERALL SAFETY SCORE"
        case .scanScoreOutOf: return "out of 100"
        case .scanIngredientsList: return "Ingredients"
        case .scanFilterButton: return "Filter"
        case .scanNoIngredientsInCategory: return "No ingredients in this category"

        case .filterAll: return "All"
        case .filterSafe: return "Safe"
        case .filterModerate: return "Moderate"
        case .filterRisky: return "Risky"

        case .ingredientBadgeSafe: return "SAFE"
        case .ingredientBadgeModerate: return "MODERATE"
        case .ingredientBadgeAvoid: return "AVOID"
        case .ingredientBadgeUnknown: return "UNKNOWN"

        case .appBrand: return "skincore."
        case .ewgScoreLabel: return "EWG Score:"
        case .matchesFound: return "matches found"
        case .noProductsForQuery: return "No products found for"
        case .nearestMatch: return "nearest match"
        case .analyzing: return "Analyzing..."
        case .ewgScore: return "EWG Score"
        case .restrictedRegion: return "restricted / potential warning"
        case .placeholderFavorites: return "Favorites"
        case .placeholderFavoritesDesc: return "Your saved products"
        case .placeholderProfile: return "Profile"
        case .placeholderComingSoon: return "Coming Soon"
        }
    }
}

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
    let userId: String
    let userName: String
    let userUsername: String?
    let userProfileImageUrl: String?
    let text: String
    let createdAt: String?
}

struct RoutineFeedItem: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userUsername: String?
    let userProfileImageUrl: String?
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
    let userId: String
    let userName: String
    let userUsername: String?
    let userProfileImageUrl: String?
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
    let userId: String
    let userName: String
    let userUsername: String?
    let userProfileImageUrl: String?
    let text: String
    let createdAt: String?
}

struct ToggleLikeResponse: Codable {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - User Profile Models

struct UserProfileResponse: Codable {
    let id: String
    let email: String
    let fullName: String?
    let skinType: String?
    let username: String?
    let bio: String?
    let profileImageUrl: String?
    let followerCount: Int
    let followingCount: Int
    let createdAt: String
    let updatedAt: String
}

struct PublicUserProfileResponse: Codable, Identifiable {
    let id: String
    let fullName: String?
    let username: String?
    let skinType: String?
    let bio: String?
    let profileImageUrl: String?
    let followerCount: Int
    let followingCount: Int
    let isFollowing: Bool
}

struct UpdateBioRequest: Codable {
    let bio: String?
}

struct UpdateProfileRequest: Codable {
    let displayName: String?
    let skinType: String?
    let username: String?
    let bio: String?
}
