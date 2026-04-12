import StoreKit
import Foundation

@MainActor
class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    static let monthlyProductID = "com.skincore.premium.monthly"
    static let yearlyProductID  = "com.skincore.premium.yearly"
    static let freeDailyLimit   = 3

    @Published var isPremium: Bool = false
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

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == Self.monthlyProductID || transaction.productID == Self.yearlyProductID {
                    hasPremium = transaction.revocationDate == nil
                }
            } catch {
                print("Transaction doğrulama hatası: \(error)")
            }
        }

        isPremium = hasPremium
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
