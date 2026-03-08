import SwiftUI
import RevenueCat

@Observable
class SubscriptionManager {
    static let shared = SubscriptionManager()

    var isProUser: Bool = false
    var isLoading: Bool = false
    var customerInfo: CustomerInfo?

    private let entitlementID = "Cooktopus Pro"

    private init() {}

    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        let apiKey = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY.isEmpty
            ? Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
            : Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
        Purchases.configure(withAPIKey: apiKey)
        #endif

        Purchases.shared.delegate = PurchaseDelegateHandler.shared
        PurchaseDelegateHandler.shared.manager = self

        Task {
            await checkSubscriptionStatus()
        }
    }

    func checkSubscriptionStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            isProUser = info.entitlements[entitlementID]?.isActive == true
        } catch {
            isProUser = false
        }
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        isProUser = info.entitlements[entitlementID]?.isActive == true
    }
}

class PurchaseDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchaseDelegateHandler()
    weak var manager: SubscriptionManager?

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.manager?.customerInfo = customerInfo
            self.manager?.isProUser = customerInfo.entitlements["Cooktopus Pro"]?.isActive == true
        }
    }
}
