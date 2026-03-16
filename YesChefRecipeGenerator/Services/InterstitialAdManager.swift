import SwiftUI
import GoogleMobileAds

@Observable
class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    private var interstitialAd: InterstitialAd?
    var isAdLoaded: Bool = false
    private var adDismissedContinuation: CheckedContinuation<Void, Never>?

    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let adUnitID = "ca-app-pub-6499414336605855/2091856261"
    #endif

    override init() {
        super.init()
    }

    func loadAd() {
        Task {
            do {
                let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.isAdLoaded = true
            } catch {
                print("[AdMob] Failed to load interstitial: \(error.localizedDescription)")
                self.isAdLoaded = false
            }
        }
    }

    func showAdAndWait() async {
        guard let ad = interstitialAd else { return }
        guard let rootVC = Self.topViewController() else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.adDismissedContinuation = continuation
            ad.present(from: rootVC)
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return nil }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitialAd = nil
            self.isAdLoaded = false
            self.adDismissedContinuation?.resume()
            self.adDismissedContinuation = nil
            self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[AdMob] Failed to present: \(error.localizedDescription)")
            self.adDismissedContinuation?.resume()
            self.adDismissedContinuation = nil
            self.loadAd()
        }
    }
}
