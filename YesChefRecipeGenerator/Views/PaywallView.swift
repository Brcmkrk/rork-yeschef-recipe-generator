import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var isPurchasing: Bool = false
    @State private var isRestoring: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoadingOfferings: Bool = true

    private let monthlyPrice: Decimal = 4.99
    private let yearlyPrice: Decimal = 39.99

    private var savingsPercentage: Int {
        let monthlyAnnualized = monthlyPrice * 12
        guard monthlyAnnualized > 0 else { return 0 }
        let savings = (monthlyAnnualized - yearlyPrice) / monthlyAnnualized * 100
        return Int(Double(truncating: savings as NSDecimalNumber).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        featuresSection
                        plansSection
                        freeTrialBanner
                        subscribeButton
                        legalSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadOfferings()
            }
            .alert(lang.t("Error", "Hata"), isPresented: $showError) {
                Button(lang.t("OK", "Tamam")) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.05),
                Color(.systemBackground),
                Color.orange.opacity(0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("MascotImage")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)

            VStack(spacing: 8) {
                Text("Cooktopus Pro")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(lang.t("Unlock unlimited recipes", "Sınırsız tariflerin kilidini aç"))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    private var featuresSection: some View {
        VStack(spacing: 14) {
            featureRow(icon: "sparkles", color: .orange,
                       text: lang.t("Unlimited AI recipe generation", "Sınırsız AI tarif oluşturma"))
            featureRow(icon: "heart.fill", color: .pink,
                       text: lang.t("Save unlimited favorites", "Sınırsız favori kaydet"))
            featureRow(icon: "globe", color: .blue,
                       text: lang.t("All cuisine types", "Tüm mutfak türleri"))
            featureRow(icon: "person.2.fill", color: .purple,
                       text: lang.t("Custom serving sizes", "Özel porsiyon boyutları"))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(.rect(cornerRadius: 8))

            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        }
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            if isLoadingOfferings {
                ProgressView()
                    .frame(height: 180)
            } else if let current = offerings?.current {
                let packages = current.availablePackages
                let yearlyPkg = packages.first { $0.packageType == .annual }
                let monthlyPkg = packages.first { $0.packageType == .monthly }

                if let yearly = yearlyPkg {
                    planCard(
                        package: yearly,
                        title: lang.t("Yearly", "Yıllık"),
                        priceLabel: formattedPrice(yearly.storeProduct.price, from: yearly.storeProduct),
                        subtitle: lang.t(
                            "per year (\(formattedMonthlyFromYearly(yearly)) per month)",
                            "yıllık (\(formattedMonthlyFromYearly(yearly)) / ay)"
                        ),
                        badge: lang.t("SAVE \(savingsPercentage)%", "%\(savingsPercentage) TASARRUF"),
                        isRecommended: true
                    )
                }

                if let monthly = monthlyPkg {
                    planCard(
                        package: monthly,
                        title: lang.t("Monthly", "Aylık"),
                        priceLabel: formattedPrice(monthly.storeProduct.price, from: monthly.storeProduct),
                        subtitle: lang.t("per month", "aylık"),
                        badge: nil,
                        isRecommended: false
                    )
                }
            } else {
                Text(lang.t("Unable to load plans", "Planlar yüklenemedi"))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func formattedPrice(_ price: Decimal, from product: RevenueCat.StoreProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.currencyCode ?? "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    private func formattedMonthlyFromYearly(_ package: Package) -> String {
        let yearlyAmount = package.storeProduct.price
        let monthly = yearlyAmount / 12
        return formattedPrice(monthly, from: package.storeProduct)
    }

    private func planCard(
        package: Package,
        title: String,
        priceLabel: String,
        subtitle: String,
        badge: String?,
        isRecommended: Bool
    ) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier

        return Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedPackage = package
            }
        } label: {
            VStack(spacing: 0) {
                if let badge {
                    Text(badge)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.capsule)
                        .padding(.top, -12)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            if isRecommended {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(priceLabel)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(isSelected ? .orange : .primary)
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(.separator).opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? .orange.opacity(0.15) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var freeTrialBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.orange)
                Text(lang.t("7-Day Free Trial", "7 Günlük Ücretsiz Deneme"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }

            Text(lang.t(
                "Try Cooktopus Pro free for 7 days. You won't be charged until the trial ends. Cancel anytime.",
                "Cooktopus Pro'yu 7 gün ücretsiz dene. Deneme süresi bitene kadar ücret alınmaz. İstediğin zaman iptal et."
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subscribeButton: some View {
        VStack(spacing: 12) {
            Button {
                guard let pkg = selectedPackage else { return }
                Task { await purchase(pkg) }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(lang.t("Start Free Trial", "Ücretsiz Denemeyi Başlat"))
                            .font(.system(.headline, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: selectedPackage != nil
                            ? [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)]
                            : [Color(.tertiarySystemFill), Color(.tertiarySystemFill)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(selectedPackage != nil ? .white : .secondary)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(
                    color: selectedPackage != nil ? .orange.opacity(0.35) : .clear,
                    radius: 12, y: 4
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedPackage == nil || isPurchasing)

            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(lang.t("Restore Purchases", "Satın Alımları Geri Yükle"))
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isRestoring)
        }
        .padding(.horizontal, 16)
    }

    private var legalSection: some View {
        VStack(spacing: 4) {
            Text(lang.t(
                "Payment will be charged to your Apple ID account at the confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.",
                "Ödeme, satın alma onayında Apple ID hesabınıza yansıtılır. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Hesabınız, mevcut dönemin bitiminden 24 saat önce yenileme için ücretlendirilir."
            ))

            HStack(spacing: 16) {
                Link(lang.t("Terms of Use", "Kullanım Koşulları"),
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link(lang.t("Privacy Policy", "Gizlilik Politikası"),
                     destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(.orange.opacity(0.8))
        }
        .font(.system(.caption2, design: .rounded))
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            offerings = try await Purchases.shared.offerings()
            if let annual = offerings?.current?.availablePackages.first(where: { $0.packageType == .annual }) {
                selectedPackage = annual
            } else {
                selectedPackage = offerings?.current?.availablePackages.first
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.customerInfo.entitlements["Cooktopus Pro"]?.isActive == true {
                await subscriptionManager.checkSubscriptionStatus()
            }
        } catch let error as RevenueCat.ErrorCode {
            if error != .purchaseCancelledError {
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await subscriptionManager.restorePurchases()
            if !subscriptionManager.isProUser {
                errorMessage = lang.t(
                    "No active subscription found. If you believe this is an error, please contact support.",
                    "Aktif abonelik bulunamadı. Bunun bir hata olduğunu düşünüyorsanız lütfen destek ile iletişime geçin."
                )
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
