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

    private let revenueCatAPIKey = "test_eFaXEqscsKQnuslQGEmAVDxmcDC"

    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: revenueCatAPIKey)

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
