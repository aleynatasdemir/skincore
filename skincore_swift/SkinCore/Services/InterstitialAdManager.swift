import GoogleMobileAds
import UIKit

@MainActor
class InterstitialAdManager: NSObject, ObservableObject {

    static let shared = InterstitialAdManager()

    private let adUnitID = "ca-app-pub-9818130828655195/7362862184"
    private var interstitial: InterstitialAd?
    @Published var isAdReady = false

    private override init() {
        super.init()
        Task { await loadAd() }
    }

    func loadAd() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
            isAdReady = true
        } catch {
            print("AdMob interstitial yüklenemedi: \(error)")
            isAdReady = false
        }
    }

    func showAd() {
        guard let ad = interstitial,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController else {
            return
        }
        ad.present(from: root)
    }
}

extension InterstitialAdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            await self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.isAdReady = false
            await self.loadAd()
        }
    }
}
