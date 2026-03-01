import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(LanguageManager.self) private var lang
    @State private var currentPage: Int = 0
    @State private var selectedLanguage: AppLanguage = .english
    @State private var animateIcon: Bool = false

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

            TabView(selection: $currentPage) {
                languagePage.tag(0)
                welcomePage.tag(1)
                featuresPage.tag(2)
                readyPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
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

                Text("Dilinizi Seçin")
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

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🍳")
                .font(.system(size: 80))
                .scaleEffect(animateIcon ? 1.1 : 0.95)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animateIcon)

            VStack(spacing: 12) {
                Text("YesChef!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(lang.t(
                    "Your personal AI recipe generator",
                    "Kişisel yapay zeka tarif oluşturucunuz"
                ))
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "carrot.fill",
                    color: .orange,
                    title: lang.t("Enter Your Ingredients", "Malzemelerini Gir"),
                    subtitle: lang.t("Tell us what's in your kitchen", "Mutfağında ne var söyle")
                )

                featureRow(
                    icon: "sparkles",
                    color: .purple,
                    title: lang.t("Get 8 Unique Recipes", "8 Eşsiz Tarif Al"),
                    subtitle: lang.t("4 exact match + 4 with extras", "4 birebir + 4 ekstra malzemeli")
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            swipeHint
        }
        .padding(16)
        .onAppear { animateIcon = true }
    }

    private var featuresPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("👨‍🍳")
                .font(.system(size: 80))

            Text(lang.t("Packed with Features", "Özelliklerle Dolu"))
                .font(.system(.title, design: .rounded, weight: .bold))

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "flame.fill",
                    color: .red,
                    title: lang.t("Cooking Mode", "Pişirme Modu"),
                    subtitle: lang.t("Step-by-step with timers", "Zamanlayıcılı adım adım")
                )
                featureRow(
                    icon: "globe",
                    color: .blue,
                    title: lang.t("8 Cuisines", "8 Mutfak"),
                    subtitle: lang.t("Turkish, Italian, Mexican & more", "Türk, İtalyan, Meksika ve dahası")
                )
                featureRow(
                    icon: "heart.fill",
                    color: .pink,
                    title: lang.t("Rate & Save", "Değerlendir ve Kaydet"),
                    subtitle: lang.t("Track recipes you've tried", "Denediğin tarifleri takip et")
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            swipeHint
        }
        .padding(16)
    }

    private var readyPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("🚀")
                    .font(.system(size: 80))

                Text(lang.t("Ready to Cook?", "Pişirmeye Hazır mısın?"))
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text(lang.t(
                    "Let's create some amazing recipes together!",
                    "Haydi birlikte harika tarifler oluşturalım!"
                ))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                onComplete()
            } label: {
                HStack(spacing: 10) {
                    Text(lang.t("Let's Go!", "Haydi Başlayalım!"))
                        .font(.system(.headline, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
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
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(16)
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

    private var swipeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
                .font(.caption)
            Text(lang.t("Swipe to continue", "Devam etmek için kaydır"))
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(.tertiary)
        .padding(.bottom, 16)
    }
}
