import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    let onUpgrade: () -> Void
    @Environment(LanguageManager.self) private var lang
    @State private var currentPage: Int = 0
    @State private var selectedLanguage: AppLanguage = .english

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    Color(red: 1, green: 0.95, blue: 0.9),
                    Color(red: 1, green: 0.92, blue: 0.85),
                    Color(red: 0.98, green: 0.94, blue: 0.9),
                    Color(red: 1, green: 0.96, blue: 0.92),
                    Color(.systemBackground),
                    Color(red: 0.98, green: 0.93, blue: 0.88),
                    Color(.systemBackground),
                    Color(red: 0.99, green: 0.95, blue: 0.9),
                    Color(.systemBackground)
                ]
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    languagePage.tag(0)
                    purposePage.tag(1)
                    howItWorksPage.tag(2)
                    smartSuggestionsPage.tag(3)
                    startCookingPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }

    private var languagePage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.4, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Choose Your Language")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("Dilinizi Se\u{00E7}in")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedLanguage = language
                            lang.current = language
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.title2)

                            Text(language.displayName)
                                .font(.system(.body, design: .rounded, weight: .semibold))

                            Spacer()

                            if selectedLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedLanguage == language
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.08), .orange.opacity(0.15)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    selectedLanguage == language ? Color.orange.opacity(0.4) : Color(.separator).opacity(0.2),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: selectedLanguage == language ? .orange.opacity(0.1) : .clear, radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            swipeHint
        }
        .padding(16)
    }

    private var purposePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 180, height: 180)

                MascotView(mood: .excited, size: 130)
                    .frame(height: 150)
            }

            VStack(spacing: 12) {
                Text(lang.t("Cook With What You Have", "Elindekilerle Pi\u{015F}ir"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(lang.t(
                    "Enter the ingredients in your kitchen and get instant recipes powered by AI.",
                    "Mutfa\u{011F}\u{0131}ndaki malzemeleri gir, yapay zeka ile an\u{0131}nda tarifler al."
                ))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }

            HStack(spacing: 16) {
                onboardingFeatureIcon(icon: "carrot.fill", color: .orange)
                onboardingFeatureIcon(icon: "sparkles", color: .purple)
                onboardingFeatureIcon(icon: "bolt.fill", color: .yellow)
            }

            Spacer()
            swipeHint
        }
        .padding(16)
    }

    private var howItWorksPage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "text.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.4, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))
            }

            VStack(spacing: 12) {
                Text(lang.t("Just Enter Your Ingredients", "Sadece Malzemelerini Gir"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(lang.t(
                    "Type the ingredients you have at home and our AI will generate a recipe for you.",
                    "Evindeki malzemeleri yaz, yapay zekam\u{0131}z senin i\u{00E7}in tarif \u{00FC}retsin."
                ))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 14) {
                stepRow(number: "1", text: lang.t("Add your ingredients", "Malzemelerini ekle"), color: .orange)
                stepRow(number: "2", text: lang.t("Choose a cuisine", "Mutfak se\u{00E7}"), color: .blue)
                stepRow(number: "3", text: lang.t("Get AI recipes instantly", "An\u{0131}nda AI tarifleri al"), color: .green)
            }
            .padding(.horizontal, 32)

            Spacer()
            swipeHint
        }
        .padding(16)
    }

    private var smartSuggestionsPage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                MascotView(mood: .cooking, size: 110)
                    .frame(height: 130)
            }

            VStack(spacing: 12) {
                Text(lang.t("Smart Recipe Suggestions", "Ak\u{0131}ll\u{0131} Tarif \u{00D6}nerileri"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(lang.t(
                    "Discover new meals based on what's already in your fridge.",
                    "Buzdolab\u{0131}nda zaten olan malzemelerle yeni yemekler ke\u{015F}fet."
                ))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 14) {
                featureRow(
                    icon: "brain.head.profile.fill",
                    color: .purple,
                    title: lang.t("AI-Powered", "Yapay Zeka Destekli"),
                    subtitle: lang.t("Smart recipe matching", "Ak\u{0131}ll\u{0131} tarif e\u{015F}le\u{015F}tirme")
                )
                featureRow(
                    icon: "globe",
                    color: .blue,
                    title: lang.t("9 Cuisines", "9 Mutfak"),
                    subtitle: lang.t("Turkish, Italian, Mexican & more", "T\u{00FC}rk, \u{0130}talyan, Meksika ve dahas\u{0131}")
                )
                featureRow(
                    icon: "flame.fill",
                    color: .red,
                    title: lang.t("Cooking Mode", "Pi\u{015F}irme Modu"),
                    subtitle: lang.t("Step-by-step with timers", "Zamanlay\u{0131}c\u{0131}l\u{0131} ad\u{0131}m ad\u{0131}m")
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            swipeHint
        }
        .padding(16)
    }

    private var startCookingPage: some View {
        VStack(spacing: 24) {
            Spacer()

            MascotView(mood: .presenting, size: 120)
                .frame(height: 140)

            VStack(spacing: 12) {
                Text(lang.t("Start Cooking for Free", "\u{00DC}cretsiz Pi\u{015F}irmeye Ba\u{015F}la"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                freeFeatureRow(
                    icon: "gift.fill",
                    text: lang.t("First 3 recipes are free", "\u{0130}lk 3 tarif \u{00FC}cretsiz")
                )
                freeFeatureRow(
                    icon: "play.rectangle.fill",
                    text: lang.t("Ads will be shown before recipes", "Tariflerden \u{00F6}nce reklam g\u{00F6}sterilecek")
                )
                freeFeatureRow(
                    icon: "crown.fill",
                    text: lang.t("Upgrade for unlimited recipes and no ads", "S\u{0131}n\u{0131}rs\u{0131}z tarif ve reklams\u{0131}z i\u{00E7}in y\u{00FC}kselt")
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.7))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "fork.knife")
                            .font(.subheadline.weight(.bold))
                        Text(lang.t("Start Cooking", "Pi\u{015F}irmeye Ba\u{015F}la"))
                            .font(.system(.headline, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: .orange.opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)

                Button {
                    onUpgrade()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                        Text(lang.t("Upgrade to Premium", "Premium'a Y\u{00FC}kselt"))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.orange)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(16)
    }

    private func onboardingFeatureIcon(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .frame(width: 56, height: 56)

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
        }
    }

    private func stepRow(number: String, text: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .clipShape(.circle)

            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func freeFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)

            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
        }
    }

    private var swipeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
                .font(.caption)
            Text(lang.t("Swipe to continue", "Devam etmek i\u{00E7}in kayd\u{0131}r"))
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(.tertiary)
        .padding(.bottom, 16)
    }
}
