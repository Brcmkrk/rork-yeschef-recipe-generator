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
                VStack(spacing: 24) {
                    statsSection
                    languageSection
                    likedRecipesSection
                    triedRecipesSection
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if likesStore.isTranslating || triedStore.isTranslating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text(lang.t("Translating recipes...", "Tarifler çevriliyor..."))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(lang.t("Profile", "Profil"))
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: lang.current) { _, newValue in
                likesStore.translateRecipes(to: newValue.rawValue)
                triedStore.translateRecipes(to: newValue.rawValue)
            }
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
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statCard(
                    icon: "fork.knife",
                    color: .orange,
                    value: "\(statsStore.totalTried)",
                    label: lang.t("Tried", "Denendi")
                )
                statCard(
                    icon: "heart.fill",
                    color: .pink,
                    value: "\(statsStore.totalLiked)",
                    label: lang.t("Liked", "Beğenildi")
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(.title2.weight(.bold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.t("Language", "Dil"), systemImage: "globe")
                .font(.headline)
                .padding(.horizontal, 16)

            HStack(spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            lang.current = language
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.flag)
                                .font(.body)
                            Text(language.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            lang.current == language
                                ? Color.orange.opacity(0.15)
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(lang.current == language ? .orange : .primary)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    lang.current == language ? Color.orange.opacity(0.4) : .clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var likedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(lang.t("Liked Recipes", "Beğenilen Tarifler"), systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Spacer()
                if !likesStore.likedRecipes.isEmpty {
                    Text("\(likesStore.likedRecipes.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            if likesStore.likedRecipes.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text(lang.t(
                        "No liked recipes yet",
                        "Henüz beğenilen tarif yok"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(lang.t(
                        "Recipes you like will appear here",
                        "Beğendiğin tarifler burada görünecek"
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 12) {
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
                Label(lang.t("Tried Recipes", "Denenen Tarifler"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Spacer()
                if !triedStore.recipes.isEmpty {
                    Text("\(triedStore.recipes.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            if triedStore.recipes.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text(lang.t(
                        "No recipes tried yet",
                        "Henüz denenen tarif yok"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(lang.t(
                        "Recipes you cook will appear here",
                        "Pişirdiğin tarifler burada görünecek"
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(triedStore.recipes) { recipe in
                        recipeRow(recipe, icon: "checkmark.circle.fill", iconColor: .green) {
                            triedStore.remove(recipe)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func recipeRow(_ recipe: Recipe, icon: String, iconColor: Color, onDelete: @escaping () -> Void) -> some View {
        Button {
            selectedRecipeId = recipe.id
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(recipe.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let recipeLang = recipe.language, recipeLang != lang.current.rawValue {
                            Text(recipeLang == "tr" ? "🇹🇷" : "🇬🇧")
                                .font(.caption2)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(recipe.cuisine)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .clipShape(.rect(cornerRadius: 5))

                        Text(recipe.difficulty)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text("\(recipe.calories) cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

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
        }
        .buttonStyle(.plain)
    }
}
