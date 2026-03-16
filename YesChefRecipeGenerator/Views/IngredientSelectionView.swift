import SwiftUI

struct IngredientSelectionView: View {
    @Bindable var viewModel: RecipeViewModel
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(LanguageManager.self) private var lang

    private var allIngredients: [String] {
        lang.current == .turkish ? IngredientPool.allTR : IngredientPool.allEN
    }

    private var filteredSuggestions: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return allIngredients.filter { ingredient in
            ingredient.lowercased().contains(query) &&
            !viewModel.selectedIngredients.contains(where: { $0.lowercased() == ingredient.lowercased() })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    searchSection

                    if !filteredSuggestions.isEmpty {
                        suggestionsSection
                    }

                    if !viewModel.selectedIngredients.isEmpty {
                        selectedChipsSection
                    }

                    luckyButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "refrigerator.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.gradient)
                .padding(.bottom, 4)

            Text(lang.t("What's in your kitchen?", "Mutfağında ne var?"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t("Search and add your ingredients", "Malzemelerini ara ve ekle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)

            TextField(
                lang.t("Search ingredients...", "Malzeme ara..."),
                text: $searchText
            )
            .focused($isSearchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit {
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.addIngredient(trimmed)
                    }
                    searchText = ""
                }
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSearchFocused ? Color.orange.opacity(0.5) : Color(.separator).opacity(0.2),
                    lineWidth: 1
                )
        )
        .animation(.smooth(duration: 0.2), value: isSearchFocused)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("Suggestions", "Öneriler"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            FlowLayout(spacing: 8) {
                ForEach(filteredSuggestions.prefix(12), id: \.self) { ingredient in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.addIngredient(ingredient)
                            searchText = ""
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                            Text(ingredient)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.orange.opacity(0.08))
                        .foregroundStyle(.orange)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var selectedChipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lang.t("Selected", "Seçilenler"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(viewModel.selectedIngredients.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.gradient)
                    .clipShape(.capsule)
            }

            FlowLayout(spacing: 8) {
                ForEach(viewModel.selectedIngredients, id: \.self) { ingredient in
                    HStack(spacing: 6) {
                        Text(ingredient)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))

                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.removeIngredient(ingredient)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(.capsule)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var luckyButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.fillRandomIngredients(language: lang.current.rawValue)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                    .font(.subheadline)
                Text(lang.t("I'm Feeling Lucky", "Şansımı Deneyeyim"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.06), .orange.opacity(0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.orange)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

