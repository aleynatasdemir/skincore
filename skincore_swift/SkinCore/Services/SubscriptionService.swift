import StoreKit
import Foundation

@MainActor
class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    static let monthlyProductID = "com.skincore.premium.monthly"
    static let yearlyProductID  = "com.skincore.premium.yearly"
    static let freeDailyLimit   = 3

    @Published var isPremium: Bool = false
    @Published var isStatusLoaded: Bool = false   // Abonelik durumu StoreKit'ten yüklendi mi?
    @Published var subscriptionExpirationDate: Date? = nil  // Aktif abonelik bitiş tarihi
    @Published var activeProductID: String? = nil           // Aktif plan ID'si
    @Published var storeProducts: [StoreKit.Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil
    @Published var showPaywallOnLaunch: Bool = false

    // Seçili plan: monthly veya yearly
    @Published var selectedProductID: String = SubscriptionService.yearlyProductID

    var monthlyProduct: StoreKit.Product? { storeProducts.first { $0.id == Self.monthlyProductID } }
    var yearlyProduct:  StoreKit.Product? { storeProducts.first { $0.id == Self.yearlyProductID  } }
    var selectedProduct: StoreKit.Product? { storeProducts.first { $0.id == selectedProductID } }

    private var updateListenerTask: Task<Void, Error>? = nil

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Ürünleri Yükle

    func loadProducts() async {
        isLoading = true
        do {
            let fetched = try await StoreKit.Product.products(for: [Self.monthlyProductID, Self.yearlyProductID])
            storeProducts = fetched
        } catch {
            print("Ürünler yüklenemedi: \(error)")
        }
        isLoading = false
    }

    // MARK: - Satın Al

    func purchase() async -> Bool {
        guard let product = selectedProduct else {
            purchaseError = "Ürün bulunamadı."
            return false
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            isLoading = false

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchaseStatus()
                await transaction.finish()
                return true

            case .userCancelled:
                return false

            case .pending:
                purchaseError = "Satın alma beklemede."
                return false

            @unknown default:
                return false
            }
        } catch {
            isLoading = false
            purchaseError = "Satın alma başarısız: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
        } catch {
            purchaseError = "Geri yükleme başarısız: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Premium Durumunu Güncelle

    func updatePurchaseStatus() async {
        var hasPremium = false
        var foundExpDate: Date? = nil
        var foundProductID: String? = nil

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == Self.monthlyProductID || transaction.productID == Self.yearlyProductID {
                    // İptal edilmemiş VE süresi dolmamış olmalı
                    let notRevoked = transaction.revocationDate == nil
                    let notExpired: Bool
                    if let expDate = transaction.expirationDate {
                        notExpired = expDate > Date()
                    } else {
                        notExpired = true
                    }
                    if notRevoked && notExpired {
                        hasPremium = true
                        foundExpDate = transaction.expirationDate
                        foundProductID = transaction.productID
                    }
                }
            } catch {
                print("Transaction doğrulama hatası: \(error)")
            }
        }

        isPremium = hasPremium
        subscriptionExpirationDate = hasPremium ? foundExpDate : nil
        activeProductID = hasPremium ? foundProductID : nil
        isStatusLoaded = true
    }

    // MARK: - Kalan Süre Metni

    /// Premium kullanıcı için "X gün kaldı", "X ay kaldı" gibi metin döndürür.
    /// Premium değilse nil döner.
    func remainingSubscriptionText(isTurkish: Bool) -> String? {
        guard isPremium, let expDate = subscriptionExpirationDate else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: now, to: expDate).day ?? 0

        // Plan tipine göre etiket
        let planLabel: String
        if activeProductID == Self.yearlyProductID {
            planLabel = isTurkish ? "Yıllık" : "Yearly"
        } else {
            planLabel = isTurkish ? "Aylık" : "Monthly"
        }

        // Bitiş tarihini formatla
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isTurkish ? "tr_TR" : "en_US")
        dateFormatter.dateFormat = isTurkish ? "d MMM yyyy" : "MMM d, yyyy"
        let expStr = dateFormatter.string(from: expDate)

        // Kalan süreyi insan dostu göster
        let remaining: String
        if totalDays <= 0 {
            remaining = isTurkish ? "Bugün bitiyor" : "Expires today"
        } else if totalDays == 1 {
            remaining = isTurkish ? "1 gün kaldı" : "1 day left"
        } else if totalDays < 31 {
            remaining = isTurkish ? "\(totalDays) gün kaldı" : "\(totalDays) days left"
        } else {
            let months = totalDays / 30
            remaining = isTurkish
                ? (months == 1 ? "1 ay kaldı" : "\(months) ay kaldı")
                : (months == 1 ? "1 month left" : "\(months) months left")
        }

        return isTurkish
            ? "\(planLabel) · \(remaining) · \(expStr)"
            : "\(planLabel) · \(remaining) · \(expStr)"
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchaseStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction hatası: \(error)")
                }
            }
        }
    }

    // MARK: - Doğrulama Kontrolü

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let signedType):
            return signedType
        }
    }

    // MARK: - Ücretsiz Tarama Hakkı Kontrolü

    func canScan() -> Bool {
        if isPremium { return true }
        return getTodaysScanCount() < Self.freeDailyLimit
    }

    func getRemainingScans() -> Int {
        if isPremium { return Int.max }
        return max(0, Self.freeDailyLimit - getTodaysScanCount())
    }

    func incrementScanCount() {
        let key = scanCountKey()
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    private func getTodaysScanCount() -> Int {
        UserDefaults.standard.integer(forKey: scanCountKey())
    }

    private func scanCountKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "scanCount_\(formatter.string(from: Date()))"
    }
}

// MARK: - Hata Tipleri

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Satın alma doğrulaması başarısız."
        }
    }
}
