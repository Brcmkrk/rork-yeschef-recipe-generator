import SwiftUI

struct PostCookingRatingView: View {
    let recipe: Recipe
    let onDone: () -> Void
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
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: rated)

                VStack(spacing: 8) {
                    Text(lang.t("How was it?", "Nasıldı?"))
                        .font(.title.weight(.bold))

                    Text(recipe.title)
                        .font(.subheadline)
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
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(width: 130, height: 130)
                            .background(Color.red.opacity(0.1))
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
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(width: 130, height: 130)
                            .background(Color.green.opacity(0.1))
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
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                onDone()
            } label: {
                Text(rated ? lang.t("Done", "Tamam") : lang.t("Skip", "Geç"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(rated ? .orange : Color(.tertiarySystemFill))
            .foregroundStyle(rated ? .white : .secondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
