import SwiftUI

struct PostCookingRatingView: View {
    let recipe: Recipe
    let onReturnToRecipes: () -> Void
    let onGoToMenu: () -> Void
    @Environment(LanguageManager.self) private var lang
    @Environment(LikesStore.self) private var likesStore
    @State private var rated: Bool = false
    @State private var ratedType: ReactionType = .none
    @State private var thumbsUpScale: CGFloat = 1.0
    @State private var thumbsDownScale: CGFloat = 1.0
    @State private var showReturnConfirmation: Bool = false
    @State private var showMenuConfirmation: Bool = false

    private var isFreeTier: Bool {
        !SubscriptionManager.shared.isProUser
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.12), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)

                    Image("MascotImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                }

                VStack(spacing: 8) {
                    Text(lang.t("How was it?", "Nasıldı?"))
                        .font(.system(.title, design: .rounded, weight: .bold))

                    Text(recipe.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                if !rated {
                    HStack(spacing: 32) {
                        Button {
                            ratedType = .dislike
                            likesStore.toggleDislike(for: recipe.id, recipe: recipe)
                            withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                                thumbsDownScale = 1.3
                                rated = true
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "hand.thumbsdown.fill")
                                    .font(.system(size: 40))
                                    .scaleEffect(thumbsDownScale)
                                Text(lang.t("Not great", "Pek değil"))
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                            }
                            .frame(width: 130, height: 130)
                            .background(
                                LinearGradient(
                                    colors: [.red.opacity(0.06), .red.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .foregroundStyle(.red)
                            .clipShape(.rect(cornerRadius: 24))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .medium), trigger: thumbsDownScale)

                        Button {
                            ratedType = .like
                            likesStore.toggleLike(for: recipe.id, recipe: recipe)
                            withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                                thumbsUpScale = 1.3
                                rated = true
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.system(size: 40))
                                    .scaleEffect(thumbsUpScale)
                                Text(lang.t("Loved it!", "Harikaydı!"))
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                            }
                            .frame(width: 130, height: 130)
                            .background(
                                LinearGradient(
                                    colors: [.green.opacity(0.06), .green.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .foregroundStyle(.green)
                            .clipShape(.rect(cornerRadius: 24))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .medium), trigger: thumbsUpScale)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: ratedType == .like ? "heart.fill" : "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ratedType == .like ? .pink : .red)
                            .transition(.scale.combined(with: .opacity))

                        Text(ratedType == .like
                             ? lang.t("Added to favorites!", "Favorilere eklendi!")
                             : lang.t("Thanks for the feedback!", "Geri bildirim için teşekkürler!"))
                            .font(.system(.headline, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                    Button {
                        showReturnConfirmation = true
                    } label: {
                        Label(lang.t("Return to Recipes", "Tariflere Dön"), systemImage: "arrow.uturn.left")
                            .font(.system(.headline, design: .rounded))
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
                            .shadow(color: .orange.opacity(0.3), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showMenuConfirmation = true
                    } label: {
                        Label(lang.t("Go to Menu", "Ana Menüye Git"), systemImage: "house.fill")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 1, green: 0.97, blue: 0.93), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert(
            lang.t("Are you sure?", "Emin misin?"),
            isPresented: $showReturnConfirmation
        ) {
            Button(lang.t("Yes, Return", "Evet, Dön"), role: .destructive) {
                onReturnToRecipes()
            }
            Button(lang.t("Cancel", "İptal"), role: .cancel) {}
        } message: {
            if isFreeTier {
                Text(lang.t(
                    "Your free recipe has already been counted. Are you sure you want to leave?",
                    "Ücretsiz tarifin zaten sayıldı. Çıkmak istediğine emin misin?"
                ))
            } else {
                Text(lang.t("You'll return to the recipes.", "Tariflere döneceksin."))
            }
        }
        .alert(
            lang.t("Are you sure?", "Emin misin?"),
            isPresented: $showMenuConfirmation
        ) {
            Button(lang.t("Go to Menu", "Ana Menüye Git"), role: .destructive) {
                onGoToMenu()
            }
            Button(lang.t("Cancel", "İptal"), role: .cancel) {}
        } message: {
            if isFreeTier {
                Text(lang.t(
                    "Your free recipe has already been counted. Are you sure you want to leave?",
                    "Ücretsiz tarifin zaten sayıldı. Çıkmak istediğine emin misin?"
                ))
            } else {
                Text(lang.t("You'll return to the main menu.", "Ana menüye döneceksin."))
            }
        }
    }
}
