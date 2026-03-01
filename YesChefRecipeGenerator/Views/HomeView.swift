import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: RecipeViewModel
    @State private var showResults: Bool = false
    @State private var showLoading: Bool = false
    @FocusState private var isEditorFocused: Bool
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
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
            .background(Color(.systemGroupedBackground))
            .onChange(of: lang.current) { _, newValue in
                viewModel.language = newValue.rawValue
            }
            .onAppear { viewModel.language = lang.current.rawValue }
            .navigationTitle("YesChef")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showLoading) {
                LoadingView {
                    viewModel.cancelGeneration()
                    showLoading = false
                }
            }
            .fullScreenCover(isPresented: $showResults) {
                ResultsView(viewModel: viewModel)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "frying.pan.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: viewModel.isLoading)

            Text(lang.t("What's in your kitchen?", "Mutfağında ne var?"))
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.t("Ingredients", "Malzemeler"), systemImage: "carrot.fill")
                .font(.headline)
                .foregroundStyle(.primary)

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
            .clipShape(.rect(cornerRadius: 14))

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.fillRandom()
                }
            } label: {
                Label(lang.t("I'm Feeling Lucky", "Şansımı Deneyeyim"), systemImage: "dice.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(lang.t("Cuisines", "Mutfaklar"), systemImage: "globe")
                    .font(.headline)

                Spacer()

                Button(lang.t("All", "Tümü")) { viewModel.selectAllCuisines() }
                    .font(.subheadline.weight(.medium))

                Text("·")
                    .foregroundStyle(.tertiary)

                Button(lang.t("Clear", "Temizle")) { viewModel.clearCuisines() }
                    .font(.subheadline.weight(.medium))
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
        .padding(.bottom, 24)
    }

    private var servingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.t("Servings", "Porsiyon"), systemImage: "person.2.fill")
                .font(.headline)

            HStack(spacing: 0) {
                ForEach(1...6, id: \.self) { count in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.servings = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                viewModel.servings == count
                                    ? Color.orange
                                    : Color(.secondarySystemGroupedBackground)
                            )
                            .foregroundStyle(viewModel.servings == count ? .white : .primary)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                isEditorFocused = false
                showLoading = true
                Task {
                    await viewModel.generateRecipes()
                    showLoading = false
                    if viewModel.hasResults && viewModel.errorMessage == nil {
                        showResults = true
                    }
                }
            } label: {
                Label(lang.t("Generate Recipes", "Tarif Oluştur"), systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!viewModel.canGenerate)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isLoading)

            if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button(lang.t("Retry", "Tekrar Dene")) {
                        showLoading = true
                        Task {
                            await viewModel.generateRecipes()
                            showLoading = false
                            if viewModel.hasResults && viewModel.errorMessage == nil {
                                showResults = true
                            }
                        }
                    }
                    .font(.footnote.weight(.semibold))
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
                Text(displayName)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.orange.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .orange : .primary)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
