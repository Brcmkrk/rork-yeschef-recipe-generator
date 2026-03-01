import SwiftUI

struct ResultsView: View {
    let viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(LikesStore.self) private var likesStore
    @Environment(LanguageManager.self) private var lang
    @State private var selectedRecipeId: String?
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
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
                .padding(.vertical, 20)
            }
            .onAppear {
                let allRecipes = viewModel.exactMatchRecipes + viewModel.extraIngredientRecipes
                likesStore.fetchGlobalCounts(for: allRecipes)
                withAnimation(.spring(duration: 0.5).delay(0.1)) {
                    appeared = true
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.02), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .overlay {
                if viewModel.isTranslating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(lang.t("Translating...", "Çevriliyor..."))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .allowsHitTesting(true)
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
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                        RecipeCardView(recipe: recipe) {
                            selectedRecipeId = recipe.id
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.08), value: appeared)
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

    private var cardGradient: LinearGradient {
        switch recipe.difficulty.lowercased() {
        case "easy", "kolay":
            return LinearGradient(colors: [.green.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "hard", "zor":
            return LinearGradient(colors: [.red.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.orange.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(recipe.cuisine)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(.rect(cornerRadius: 6))

                    Text(recipe.difficulty)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor.opacity(0.12))
                        .foregroundStyle(difficultyColor)
                        .clipShape(.rect(cornerRadius: 6))

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(recipe.calories)")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }

                Text(recipe.title)
                    .font(.system(.headline, design: .rounded))
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
                            Image(systemName: likesStore.reaction(for: recipe.id) == .like ? "heart.fill" : "heart")
                                .font(.subheadline)
                                .foregroundStyle(likesStore.reaction(for: recipe.id) == .like ? .pink : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                            let likeCount = likesStore.likesCount(for: recipe.id)
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(likesStore.reaction(for: recipe.id) == .like ? .pink : .secondary)
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
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(likesStore.reaction(for: recipe.id) == .dislike ? .red : .secondary)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: likesStore.reaction(for: recipe.id) == .dislike)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(lang.t("View", "Gör"))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .frame(width: 270, height: 250)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    cardGradient
                }
            )
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}
