import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: RecipeViewModel
    @State private var showFlow: Bool = false
    @State private var showPaywall: Bool = false
    @State private var animateCards: Bool = false
    @Environment(LanguageManager.self) private var lang
    @Environment(FreeRecipeTracker.self) private var freeRecipeTracker
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    howItWorksSection
                    startButton

                    if !subscriptionManager.isProUser {
                        freeRecipesBadge
                    }
                }
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.04), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("MascotImage")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                        Text("Cooktopus")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .fullScreenCover(isPresented: $showFlow) {
                RecipeFlowContainerView(viewModel: viewModel)
                    .onAppear {
                        viewModel.language = lang.current.rawValue
                    }
            }
            .onChange(of: viewModel.shouldReturnToHome) { _, newValue in
                if newValue {
                    showFlow = false
                    viewModel.shouldReturnToHome = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewModel.resetFlow()
                    }
                }
            }
            .onChange(of: lang.current) { _, newValue in
                viewModel.translateIfNeeded(to: newValue.rawValue)
            }
            .onAppear {
                viewModel.language = lang.current.rawValue
                withAnimation(.spring(duration: 0.6).delay(0.2)) {
                    animateCards = true
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.12), .orange.opacity(0.02), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image("MascotImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            }

            VStack(spacing: 6) {
                Text(lang.t("Welcome to Cooktopus!", "Cooktopus'a Hoş Geldin!"))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(lang.t(
                    "Turn your ingredients into delicious recipes with AI",
                    "Malzemelerini AI ile lezzetli tariflere dönüştür"
                ))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }
        }
        .padding(.top, 24)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("How It Works", "Nasıl Çalışır"))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                FlowStepCard(
                    number: 1,
                    icon: "refrigerator.fill",
                    color: .orange,
                    title: lang.t("Add Your Ingredients", "Malzemelerini Ekle"),
                    description: lang.t("Tell us what's in your kitchen", "Mutfağında ne olduğunu söyle"),
                    appeared: animateCards,
                    delay: 0.0
                )

                FlowStepCard(
                    number: 2,
                    icon: "globe",
                    color: .blue,
                    title: lang.t("Pick Cuisines", "Mutfak Seç"),
                    description: lang.t("Choose your favorite food styles", "Favori yemek tarzlarını seç"),
                    appeared: animateCards,
                    delay: 0.08
                )

                FlowStepCard(
                    number: 3,
                    icon: "person.2.fill",
                    color: .purple,
                    title: lang.t("Set Servings", "Porsiyon Belirle"),
                    description: lang.t("How many people are eating?", "Kaç kişilik yemek?"),
                    appeared: animateCards,
                    delay: 0.16
                )

                FlowStepCard(
                    number: 4,
                    icon: "sparkles",
                    color: .mint,
                    title: lang.t("Generate Recipes", "Tarif Oluştur"),
                    description: lang.t("AI creates personalized recipes for you", "AI sana özel tarifler oluşturur"),
                    appeared: animateCards,
                    delay: 0.24
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private var startButton: some View {
        Button {
            if !subscriptionManager.isProUser && freeRecipeTracker.hasReachedLimit {
                showPaywall = true
            } else {
                showFlow = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                Text(lang.t("Let's Cook!", "Hadi Pişirelim!"))
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
            .shadow(color: .orange.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .sensoryFeedback(.impact(weight: .medium), trigger: showFlow)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var freeRecipesBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: freeRecipeTracker.hasReachedLimit ? "exclamationmark.triangle.fill" : "gift.fill")
                .foregroundStyle(freeRecipeTracker.hasReachedLimit ? .red : .orange)
            Text(freeRecipeTracker.hasReachedLimit
                 ? lang.t("No free recipes left this month", "Bu ay ücretsiz tarif hakkın kalmadı")
                 : lang.t(
                    "\(freeRecipeTracker.remainingFreeRecipes) free recipes remaining",
                    "\(freeRecipeTracker.remainingFreeRecipes) ücretsiz tarif kaldı"
                 ))
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            Spacer()
            if freeRecipeTracker.hasReachedLimit {
                Button {
                    showPaywall = true
                } label: {
                    Text("Pro")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(LinearGradient(colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(.capsule)
                }
            }
        }
        .padding(14)
        .background(freeRecipeTracker.hasReachedLimit ? Color.red.opacity(0.06) : Color.orange.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
}

struct FlowStepCard: View {
    let number: Int
    let icon: String
    let color: Color
    let title: String
    let description: String
    let appeared: Bool
    let delay: Double
    @State private var isExpanded: Bool = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    if isExpanded {
                        Text(description)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.symbolEffect(.replace))

                Text("\(number)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(color.gradient)
                    .clipShape(Circle())
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(duration: 0.5).delay(delay), value: appeared)
    }
}
