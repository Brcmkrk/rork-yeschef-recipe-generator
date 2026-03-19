import SwiftUI

struct PostCookingRatingView: View {
    let recipe: Recipe
    let onGoToMenu: () -> Void
    @Environment(LanguageManager.self) private var lang
    @Environment(LikesStore.self) private var likesStore
    @State private var rated: Bool = false
    @State private var ratedType: ReactionType = .none
    @State private var thumbsUpScale: CGFloat = 1.0
    @State private var thumbsDownScale: CGFloat = 1.0


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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                onGoToMenu()
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                onGoToMenu()
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


        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 1, green: 0.97, blue: 0.93), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )

    }
}
