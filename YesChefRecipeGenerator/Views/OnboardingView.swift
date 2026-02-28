import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(LanguageManager.self) private var lang
    @State private var currentPage: Int = 0
    @State private var selectedLanguage: AppLanguage = .english
    @State private var animateIcon: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
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

            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)

            Text("Choose Your Language")
                .font(.title.weight(.bold))

            Text("Dilinizi Seçin")
                .font(.title3)
                .foregroundStyle(.secondary)

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
                                .font(.body.weight(.semibold))

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
                                ? Color.orange.opacity(0.1)
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    selectedLanguage == language ? Color.orange.opacity(0.4) : .clear,
                                    lineWidth: 2
                                )
                        )
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
                    .font(.largeTitle.weight(.bold))

                Text(lang.t(
                    "Your personal AI recipe generator",
                    "Kişisel yapay zeka tarif oluşturucunuz"
                ))
                .font(.title3)
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
                .font(.title.weight(.bold))

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
                    .font(.title.weight(.bold))

                Text(lang.t(
                    "Let's create some amazing recipes together!",
                    "Haydi birlikte harika tarifler oluşturalım!"
                ))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                onComplete()
            } label: {
                Label(
                    lang.t("Let's Go!", "Haydi Başlayalım!"),
                    systemImage: "arrow.right"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(16)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
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
                .font(.caption)
        }
        .foregroundStyle(.tertiary)
        .padding(.bottom, 16)
    }
}
