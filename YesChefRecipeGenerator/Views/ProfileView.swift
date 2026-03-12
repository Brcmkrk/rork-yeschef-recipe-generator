import SwiftUI

struct ProfileView: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(LikesStore.self) private var likesStore
    @Environment(TriedRecipesStore.self) private var triedStore
    @Environment(StatsStore.self) private var statsStore
    @State private var selectedRecipeId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    statsSection
                    likedRecipesSection
                    triedRecipesSection
                }
                .padding(.vertical, 16)
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
                if likesStore.isTranslating || triedStore.isTranslating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text(lang.t("Translating recipes...", "Tarifler çevriliyor..."))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(lang.t("Profile", "Profil"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: Binding(
                get: { selectedRecipeId != nil },
                set: { if !$0 { selectedRecipeId = nil } }
            )) {
                if let id = selectedRecipeId,
                   let recipe = (likesStore.likedRecipes + triedStore.recipes).first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: recipe, viewModel: RecipeViewModel())
                }
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 14) {
            statCard(
                icon: "fork.knife",
                gradient: [Color(red: 0.95, green: 0.5, blue: 0.1), .orange],
                value: "\(statsStore.totalTried)",
                label: lang.t("Tried", "Denendi")
            )
            statCard(
                icon: "heart.fill",
                gradient: [.pink, Color(red: 0.9, green: 0.3, blue: 0.4)],
                value: "\(statsStore.totalLiked)",
                label: lang.t("Liked", "Beğenildi")
            )
        }
        .padding(.horizontal, 16)
    }

    private func statCard(icon: String, gradient: [Color], value: String, label: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 6, y: 2)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var likedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text(lang.t("Liked Recipes", "Beğenilen Tarifler"))
                        .font(.system(.headline, design: .rounded))
                }
                Spacer()
                if !likesStore.likedRecipes.isEmpty {
                    Text("\(likesStore.likedRecipes.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)

            if likesStore.likedRecipes.isEmpty {
                VStack(spacing: 14) {
                    Image("MascotImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .opacity(0.4)

                    Text(lang.t("No liked recipes yet", "Henüz beğenilen tarif yok"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(lang.t("Recipes you like will appear here", "Beğendiğin tarifler burada görünecek"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 18))
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(likesStore.likedRecipes) { recipe in
                        recipeRow(recipe, icon: "heart.fill", iconColor: .pink) {
                            likesStore.hideFromProfile(recipe)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var triedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(lang.t("Tried Recipes", "Denenen Tarifler"))
                        .font(.system(.headline, design: .rounded))
                }
                Spacer()
                if !triedStore.recipes.isEmpty {
                    Text("\(triedStore.recipes.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)

            if triedStore.recipes.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text(lang.t("No recipes tried yet", "Henüz denenen tarif yok"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(lang.t("Recipes you cook will appear here", "Pişirdiğin tarifler burada görünecek"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 18))
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(triedStore.recipes) { recipe in
                        recipeRow(recipe, icon: "checkmark.circle.fill", iconColor: .green, showLikeToggle: true) {
                            triedStore.remove(recipe)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func recipeRow(_ recipe: Recipe, icon: String, iconColor: Color, onDelete: @escaping () -> Void, showLikeToggle: Bool = false) -> some View {
        Button {
            selectedRecipeId = recipe.id
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(recipe.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let recipeLang = recipe.language, recipeLang != lang.current.rawValue {
                            Text(recipeLang == "tr" ? "\u{1F1F9}\u{1F1F7}" : "\u{1F1EC}\u{1F1E7}")
                                .font(.caption2)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(recipe.cuisine)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .clipShape(.rect(cornerRadius: 5))

                        Text(recipe.difficulty)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                            Text("\(recipe.calories)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if showLikeToggle {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            likesStore.toggleLike(for: recipe.id, recipe: recipe)
                        }
                    } label: {
                        Image(systemName: likesStore.reaction(for: recipe.id) == .like ? "heart.fill" : "heart")
                            .font(.body)
                            .foregroundStyle(likesStore.reaction(for: recipe.id) == .like ? .pink : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.6))
                        .padding(8)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }
}
