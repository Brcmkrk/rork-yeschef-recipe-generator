import SwiftUI

struct RecipeFlowContainerView: View {
    @Bindable var viewModel: RecipeViewModel
    @State private var currentStep: Int = 0
    @State private var showResults: Bool = false
    @State private var showLoading: Bool = false
    @State private var recipesReady: Bool = false
    @State private var pendingShowResults: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showExitConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(FreeRecipeTracker.self) private var freeRecipeTracker

    private let totalSteps = 4

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !viewModel.selectedIngredients.isEmpty
        case 1: return !viewModel.selectedCuisines.isEmpty
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 8)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.03), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if viewModel.selectedIngredients.isEmpty && viewModel.selectedCuisines.isEmpty {
                            dismiss()
                        } else {
                            showExitConfirmation = true
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
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
            .alert(
                lang.t("Leave Recipe Flow?", "Tarif Akışından Çık?"),
                isPresented: $showExitConfirmation
            ) {
                Button(lang.t("Yes, Leave", "Evet, Çık"), role: .destructive) {
                    viewModel.shouldReturnToHome = true
                }
                Button(lang.t("Cancel", "İptal"), role: .cancel) {}
            } message: {
                Text(lang.t(
                    "Your selections will be lost.",
                    "Seçimleriniz kaybolacak."
                ))
            }
            .fullScreenCover(isPresented: $showLoading, onDismiss: {
                if pendingShowResults {
                    pendingShowResults = false
                    showResults = true
                }
            }) {
                LoadingView(
                    recipesReady: recipesReady,
                    onCancel: {
                        viewModel.cancelGeneration()
                        pendingShowResults = false
                        showLoading = false
                        recipesReady = false
                    },
                    onShowRecipes: {
                        recipesReady = false
                        if viewModel.hasResults && viewModel.errorMessage == nil {
                            if !subscriptionManager.isProUser {
                                freeRecipeTracker.incrementUsage()
                            }
                            pendingShowResults = true
                        }
                        showLoading = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showResults) {
                ResultsView(viewModel: viewModel, onRefresh: {
                    showResults = false
                    recipesReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showLoading = true
                        Task {
                            await viewModel.refreshRecipes()
                            if viewModel.hasResults && viewModel.errorMessage == nil {
                                recipesReady = true
                            } else {
                                showLoading = false
                            }
                        }
                    }
                })
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onChange(of: viewModel.shouldReturnToHome) { _, newValue in
                if newValue {
                    showResults = false
                    showLoading = false
                }
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.orange : Color(.tertiarySystemFill))
                        .frame(height: 4)
                        .animation(.spring(duration: 0.35), value: currentStep)
                }
            }
            .padding(.horizontal, 20)

            Text(lang.t("Step \(currentStep + 1) of \(totalSteps)", "\(currentStep + 1). adım / \(totalSteps)"))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch currentStep {
            case 0:
                IngredientSelectionView(viewModel: viewModel)
            case 1:
                CuisineSelectionView(viewModel: viewModel)
            case 2:
                ServingSelectionView(viewModel: viewModel)
            case 3:
                MatchPreferenceView(viewModel: viewModel)
            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if currentStep == totalSteps - 1 {
                freeRecipesBanner
            }

            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            currentStep -= 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text(lang.t("Back", "Geri"))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if currentStep < totalSteps - 1 {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            currentStep += 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(lang.t("Next", "İleri"))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canProceed
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color(.tertiarySystemFill))
                        )
                        .foregroundStyle(canProceed ? .white : .secondary)
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: canProceed ? .orange.opacity(0.3) : .clear, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed)
                    .sensoryFeedback(.impact(weight: .light), trigger: currentStep)
                } else {
                    Button {
                        handleGenerate()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                            Text(lang.t("Generate Recipes", "Tarif Oluştur"))
                                .font(.system(.headline, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: .orange.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isLoading)
                }
            }

            if let error = viewModel.errorMessage, currentStep == totalSteps - 1 {
                VStack(spacing: 6) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button(lang.t("Retry", "Tekrar Dene")) {
                        handleGenerate()
                    }
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var freeRecipesBanner: some View {
        if !subscriptionManager.isProUser {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.orange)
                Text(lang.t(
                    "\(freeRecipeTracker.remainingFreeRecipes) free recipes remaining",
                    "\(freeRecipeTracker.remainingFreeRecipes) ücretsiz tarif kaldı"
                ))
                .font(.system(.subheadline, design: .rounded, weight: .medium))

                Spacer()

                Button {
                    showPaywall = true
                } label: {
                    Text(lang.t("Upgrade", "Yükselt"))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func handleGenerate() {
        if !subscriptionManager.isProUser && freeRecipeTracker.hasReachedLimit {
            showPaywall = true
            return
        }

        viewModel.syncFlowToGeneration()
        let ingredients = viewModel.selectedIngredients
        let language = viewModel.language
        recipesReady = false
        showLoading = true

        let servings = viewModel.servings
        let cuisineCount = viewModel.selectedCuisines.count
        let exactMatchCount = viewModel.exactMatchCount
        let extraMatchCount = viewModel.extraIngredientCount

        Task {
            let startTime = Date()
            await viewModel.generateRecipes()
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
            if viewModel.hasResults && viewModel.errorMessage == nil {
                recipesReady = true
                await SupabaseService.shared.saveSearchedIngredientsWithTime(ingredients, language: language, generationTimeMs: elapsedMs, servings: servings, cuisineCount: cuisineCount, exactMatchCount: exactMatchCount, extraMatchCount: extraMatchCount)
            } else {
                showLoading = false
            }
        }
    }
}
