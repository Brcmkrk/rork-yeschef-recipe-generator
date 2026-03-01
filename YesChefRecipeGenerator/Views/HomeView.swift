import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: RecipeViewModel
    @State private var showResults: Bool = false
    @State private var showLoading: Bool = false
    @State private var recipesReady: Bool = false
    @State private var pendingShowResults: Bool = false
    @FocusState private var isEditorFocused: Bool
    @Environment(LanguageManager.self) private var lang
    @State private var headerPulse: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    ingredientsSection
                    cuisineSection
                    servingsSection
                    generateButton
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isEditorFocused = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(lang.t("Done", "Tamam")) { isEditorFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.03), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onChange(of: lang.current) { _, newValue in
                viewModel.translateIfNeeded(to: newValue.rawValue)
            }
            .onAppear {
                viewModel.language = lang.current.rawValue
                headerPulse = true
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("YesChef")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                }
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
                            pendingShowResults = true
                        }
                        showLoading = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showResults) {
                ResultsView(viewModel: viewModel)
            }
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.15), .orange.opacity(0.03), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(headerPulse ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: headerPulse)

                Image(systemName: "frying.pan.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.45, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: viewModel.isLoading)
            }

            Text(lang.t("What's in your kitchen?", "Mutfağında ne var?"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text(lang.t("Let's cook something delicious", "Haydi lezzetli bir şeyler pişirelim"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "carrot.fill")
                    .foregroundStyle(.orange)
                Text(lang.t("Ingredients", "Malzemeler"))
                    .font(.system(.headline, design: .rounded))
            }

            ZStack(alignment: .topLeading) {
                if viewModel.ingredientsText.isEmpty {
                    Text(lang.t(
                        "chicken, rice, tomatoes, onions...",
                        "tavuk, pirinç, domates, soğan..."
                    ))
                    .foregroundStyle(Color(.placeholderText))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                TextEditor(text: $viewModel.ingredientsText)
                    .focused($isEditorFocused)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isEditorFocused ? Color.orange.opacity(0.4) : Color(.separator).opacity(0.3),
                        lineWidth: 1
                    )
            )
            .animation(.smooth(duration: 0.2), value: isEditorFocused)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.fillRandom()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dice.fill")
                        .font(.subheadline)
                    Text(lang.t("I'm Feeling Lucky", "Şansımı Deneyeyim"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.orange.opacity(0.08), .orange.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.orange)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundStyle(.blue)
                    Text(lang.t("Cuisines", "Mutfaklar"))
                        .font(.system(.headline, design: .rounded))
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(lang.t("All", "Tümü")) { viewModel.selectAllCuisines() }
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.orange)

                    Button(lang.t("Clear", "Temizle")) { viewModel.clearCuisines() }
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(Cuisine.allCases) { cuisine in
                    CuisineChipView(
                        cuisine: cuisine,
                        isSelected: viewModel.selectedCuisines.contains(cuisine)
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.toggleCuisine(cuisine)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var servingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.purple)
                Text(lang.t("Servings", "Porsiyon"))
                    .font(.system(.headline, design: .rounded))
            }

            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { count in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.servings = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.servings == count
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                            )
                            .foregroundStyle(viewModel.servings == count ? .white : .primary)
                            .clipShape(.rect(cornerRadius: 12))
                            .shadow(
                                color: viewModel.servings == count ? .orange.opacity(0.3) : .clear,
                                radius: 6, y: 2
                            )
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.servings)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                isEditorFocused = false
                recipesReady = false
                showLoading = true
                Task {
                    await viewModel.generateRecipes()
                    recipesReady = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text(lang.t("Generate Recipes", "Tarif Oluştur"))
                        .font(.system(.headline, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: viewModel.canGenerate
                            ? [.orange, Color(red: 0.85, green: 0.35, blue: 0.1)]
                            : [Color(.tertiarySystemFill), Color(.tertiarySystemFill)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(viewModel.canGenerate ? .white : .secondary)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(
                    color: viewModel.canGenerate ? .orange.opacity(0.35) : .clear,
                    radius: 12, y: 4
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canGenerate)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isLoading)

            if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button(lang.t("Retry", "Tekrar Dene")) {
                        recipesReady = false
                        showLoading = true
                        Task {
                            await viewModel.generateRecipes()
                            recipesReady = true
                        }
                    }
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct CuisineChipView: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let action: () -> Void
    @Environment(LanguageManager.self) private var lang

    private var displayName: String {
        switch cuisine {
        case .turkish: return lang.t("Turkish", "Türk")
        case .italian: return lang.t("Italian", "İtalyan")
        case .mexican: return lang.t("Mexican", "Meksika")
        case .asian: return lang.t("Asian", "Asya")
        case .french: return lang.t("French", "Fransız")
        case .mediterranean: return lang.t("Mediterranean", "Akdeniz")
        case .american: return lang.t("American", "Amerikan")
        case .indian: return lang.t("Indian", "Hint")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: cuisine.icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                Text(displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.1), .orange.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? .orange : .primary)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.5) : Color(.separator).opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? .orange.opacity(0.1) : .clear, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
