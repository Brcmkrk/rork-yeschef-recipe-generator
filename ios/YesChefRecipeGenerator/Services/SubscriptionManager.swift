import SwiftUI
import RevenueCat

@Observable
class SubscriptionManager {
    static let shared = SubscriptionManager()

    var isProUser: Bool = false
    var isLoading: Bool = false
    var customerInfo: CustomerInfo?
    var subscriptionPeriod: SubscriptionPeriodType = .unknown

    nonisolated enum SubscriptionPeriodType: Sendable {
        case monthly
        case yearly
        case unknown
    }

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
            updatePeriod(from: info)
        } catch {
            isProUser = false
        }
    }

    func updatePeriod(from info: CustomerInfo) {
        guard let entitlement = info.entitlements[entitlementID], entitlement.isActive else {
            subscriptionPeriod = .unknown
            return
        }
        let productId = entitlement.productIdentifier.lowercased()
        if productId.contains("year") || productId.contains("annual") {
            subscriptionPeriod = .yearly
        } else if productId.contains("month") {
            subscriptionPeriod = .monthly
        } else {
            subscriptionPeriod = .unknown
        }
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        isProUser = info.entitlements[entitlementID]?.isActive == true
        updatePeriod(from: info)
    }
}

class PurchaseDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchaseDelegateHandler()
    weak var manager: SubscriptionManager?

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.manager?.customerInfo = customerInfo
            self.manager?.isProUser = customerInfo.entitlements["Cooktopus Pro"]?.isActive == true
            self.manager?.updatePeriod(from: customerInfo)
        }
    }
}
