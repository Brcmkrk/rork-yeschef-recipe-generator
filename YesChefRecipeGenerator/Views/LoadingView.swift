import SwiftUI

struct LoadingView: View {
    let onCancel: () -> Void
    @Environment(LanguageManager.self) private var lang

    @State private var currentEmoji: Int = 0
    @State private var bouncePhase: Bool = false
    @State private var textIndex: Int = 0
    @State private var dotCount: Int = 0
    @State private var steamOffset: CGFloat = 0

    private let emojis = ["🍳", "🥘", "🍲", "🔥", "🧑‍🍳", "🥄", "🍽️", "✨"]

    private var loadingTexts: [String] {
        [
            lang.t("Chopping ingredients...", "Malzemeler doğranıyor..."),
            lang.t("Heating the pan...", "Tava ısıtılıyor..."),
            lang.t("Adding spices...", "Baharatlar ekleniyor..."),
            lang.t("Stirring the pot...", "Tencere karıştırılıyor..."),
            lang.t("Tasting for flavor...", "Lezzet kontrolü yapılıyor..."),
            lang.t("Almost ready...", "Neredeyse hazır..."),
            lang.t("Plating up...", "Tabağa alınıyor..."),
        ]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }

                Spacer()

                VStack(spacing: 32) {
                    ZStack {
                        ForEach(0..<8, id: \.self) { index in
                            Text(emojis[index])
                                .font(.system(size: 28))
                                .offset(
                                    x: cos(Double(index) * .pi / 4 + Double(currentEmoji) * 0.5) * 60,
                                    y: sin(Double(index) * .pi / 4 + Double(currentEmoji) * 0.5) * 60
                                )
                                .opacity(index == currentEmoji % 8 ? 1 : 0.3)
                                .scaleEffect(index == currentEmoji % 8 ? 1.3 : 0.8)
                        }

                        Text("🍳")
                            .font(.system(size: 64))
                            .scaleEffect(bouncePhase ? 1.15 : 0.95)
                            .rotationEffect(.degrees(bouncePhase ? 5 : -5))
                    }
                    .frame(width: 160, height: 160)

                    VStack(spacing: 16) {
                        Text(loadingTexts[textIndex % loadingTexts.count])
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.4), value: textIndex)

                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(dotCount % 3 == i ? 1.4 : 0.7)
                                    .opacity(dotCount % 3 == i ? 1 : 0.3)
                            }
                        }

                        Text(lang.t("Our chef is preparing your recipes", "Şefimiz tariflerinizi hazırlıyor"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("YesChef")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            bouncePhase = true
        }

        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.spring(duration: 0.3)) {
                    currentEmoji += 1
                }
            }
        }

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.spring(duration: 0.2)) {
                    dotCount += 1
                }
            }
        }

        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    textIndex += 1
                }
            }
        }
    }
}
