import SwiftUI

struct RatingView: View {
    let recipes: [Recipe]
    let onDone: () -> Void
    @Environment(LanguageManager.self) private var lang
    @Environment(LikesStore.self) private var likesStore
    @State private var currentIndex: Int = 0
    @State private var ratedCount: Int = 0
    @State private var showConfetti: Bool = false
    @State private var cardOffset: CGFloat = 0

    private var currentRecipe: Recipe? {
        guard currentIndex < recipes.count else { return nil }
        return recipes[currentIndex]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                if let recipe = currentRecipe {
                    recipeCard(recipe)
                        .offset(x: cardOffset)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(recipe.id)

                    ratingButtons(recipe)

                    Text(lang.t(
                        "\(currentIndex + 1) of \(recipes.count)",
                        "\(currentIndex + 1) / \(recipes.count)"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    completionView
                }

                Spacer()
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(lang.t("Rate Your Recipes", "Tarifleri Değerlendir"))
                .font(.title2.weight(.bold))

            Text(lang.t(
                "Swipe through and rate each recipe",
                "Her tarifi değerlendir"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            ProgressView(value: Double(currentIndex), total: Double(recipes.count))
                .tint(.orange)
                .padding(.top, 8)
        }
        .padding(.top, 16)
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
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
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(.rect(cornerRadius: 6))

                Spacer()

                Text("\(recipe.calories) cal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(recipe.title)
                .font(.title3.weight(.bold))
                .lineLimit(2)

            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !recipe.ingredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.ingredients.prefix(6)) { ingredient in
                            Text(ingredient.name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "list.number")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(lang.t("\(recipe.steps.count) steps", "\(recipe.steps.count) adım"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func ratingButtons(_ recipe: Recipe) -> some View {
        HStack(spacing: 20) {
            Button {
                likesStore.toggleDislike(for: recipe.id)
                advanceCard()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.title2)
                    Text(lang.t("Not for me", "Bana göre değil"))
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Button {
                advanceCard()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                    Text(lang.t("Skip", "Geç"))
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(.tertiarySystemFill))
                .foregroundStyle(.secondary)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Button {
                likesStore.toggleLike(for: recipe.id)
                advanceCard()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.title2)
                    Text(lang.t("Love it!", "Harika!"))
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green.opacity(0.1))
                .foregroundStyle(.green)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: currentIndex)
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🎉")
                .font(.system(size: 72))
                .scaleEffect(showConfetti ? 1.2 : 0.8)
                .animation(.spring(duration: 0.5, bounce: 0.6), value: showConfetti)

            Text(lang.t("All Done!", "Tamamlandı!"))
                .font(.title.weight(.bold))

            Text(lang.t(
                "You've rated all recipes. Head back to explore them!",
                "Tüm tarifleri değerlendirdin. Keşfetmeye başla!"
            ))
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                onDone()
            } label: {
                Label(
                    lang.t("View Recipes", "Tarifleri Gör"),
                    systemImage: "arrow.right"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            showConfetti = true
        }
    }

    private func advanceCard() {
        withAnimation(.spring(duration: 0.35)) {
            currentIndex += 1
        }
    }
}
