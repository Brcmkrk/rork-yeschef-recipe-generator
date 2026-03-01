import SwiftUI

struct ResultsView: View {
    let viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(LikesStore.self) private var likesStore
    @Environment(LanguageManager.self) private var lang
    @State private var selectedRecipeId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !viewModel.exactMatchRecipes.isEmpty {
                        recipeSection(
                            title: lang.t("Exact Match", "Birebir Eşleşme"),
                            subtitle: lang.t("Using only your ingredients", "Sadece senin malzemelerin"),
                            icon: "checkmark.seal.fill",
                            color: .green,
                            recipes: viewModel.exactMatchRecipes
                        )
                    }

                    if !viewModel.extraIngredientRecipes.isEmpty {
                        recipeSection(
                            title: lang.t("New Flavors", "Yeni Lezzetler"),
                            subtitle: lang.t("With a few extra ingredients", "Birkaç ekstra malzemeyle"),
                            icon: "sparkles",
                            color: .purple,
                            recipes: viewModel.extraIngredientRecipes
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .onAppear {
                let allRecipes = viewModel.exactMatchRecipes + viewModel.extraIngredientRecipes
                likesStore.fetchGlobalCounts(for: allRecipes)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if viewModel.isTranslating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(lang.t("Translating...", "Çevriliyor..."))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(lang.t("Your Recipes", "Tariflerin"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: lang.current) { _, newValue in
                viewModel.translateIfNeeded(to: newValue.rawValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedRecipeId != nil },
                set: { if !$0 { selectedRecipeId = nil } }
            )) {
                if let id = selectedRecipeId,
                   let recipe = (viewModel.exactMatchRecipes + viewModel.extraIngredientRecipes).first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: recipe, viewModel: viewModel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func recipeSection(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        recipes: [Recipe]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recipes) { recipe in
                        RecipeCardView(recipe: recipe) {
                            selectedRecipeId = recipe.id
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 16)
        }
    }
}

struct RecipeCardView: View {
    let recipe: Recipe
    let onTap: () -> Void
    @Environment(LikesStore.self) private var likesStore
    @Environment(LanguageManager.self) private var lang

    private var difficultyColor: Color {
        switch recipe.difficulty.lowercased() {
        case "easy", "kolay": return .green
        case "medium", "orta": return .orange
        case "hard", "zor": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(recipe.cuisine)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(.rect(cornerRadius: 6))

                    Text(recipe.difficulty)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor.opacity(0.15))
                        .foregroundStyle(difficultyColor)
                        .clipShape(.rect(cornerRadius: 6))

                    Spacer()

                    Text("\(recipe.calories) cal")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(recipe.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if !recipe.required_extra_ingredients.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text(recipe.required_extra_ingredients.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            likesStore.toggleLike(for: recipe.id, recipe: recipe)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: likesStore.reaction(for: recipe.id) == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.subheadline)
                                .foregroundStyle(likesStore.reaction(for: recipe.id) == .like ? .green : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                            let likeCount = likesStore.likesCount(for: recipe.id)
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(likesStore.reaction(for: recipe.id) == .like ? .green : .secondary)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: likesStore.reaction(for: recipe.id) == .like)

                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            likesStore.toggleDislike(for: recipe.id, recipe: recipe)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: likesStore.reaction(for: recipe.id) == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.subheadline)
                                .foregroundStyle(likesStore.reaction(for: recipe.id) == .dislike ? .red : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                            let dislikeCount = likesStore.dislikesCount(for: recipe.id)
                            if dislikeCount > 0 {
                                Text("\(dislikeCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(likesStore.reaction(for: recipe.id) == .dislike ? .red : .secondary)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: likesStore.reaction(for: recipe.id) == .dislike)

                    Spacer()

                    Text(lang.t("View", "Gör"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .frame(width: 260, height: 240)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
