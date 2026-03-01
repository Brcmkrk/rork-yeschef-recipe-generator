import SwiftUI

struct FallingFood: Identifiable {
    let id = UUID()
    let emoji: String
    let x: CGFloat
    var y: CGFloat
    let speed: CGFloat
    let size: CGFloat
    var caught: Bool = false
}

@Observable
class FoodGameState {
    var foods: [FallingFood] = []
    var score: Int = 0
    var missedCount: Int = 0
    var gameActive: Bool = true
    var recipesReady: Bool = false
    var showBanner: Bool = false

    private let foodEmojis = ["🍕", "🌮", "🍣", "🥐", "🍔", "🍩", "🥑", "🍇", "🧁", "🍗", "🥟", "🍰", "🫐", "🥙", "🍝"]

    func spawnFood(in width: CGFloat) {
        let emoji = foodEmojis.randomElement() ?? "🍕"
        let x = CGFloat.random(in: 40...(width - 40))
        let speed = CGFloat.random(in: 1.5...3.5)
        let size = CGFloat.random(in: 28...44)
        let food = FallingFood(emoji: emoji, x: x, y: -50, speed: speed, size: size)
        foods.append(food)
    }

    func catchFood(at point: CGPoint) -> Bool {
        for i in foods.indices.reversed() {
            let food = foods[i]
            if !food.caught {
                let dx = abs(food.x - point.x)
                let dy = abs(food.y - point.y)
                if dx < 40 && dy < 40 {
                    foods[i].caught = true
                    score += 1
                    return true
                }
            }
        }
        return false
    }

    func tick() {
        for i in foods.indices {
            if !foods[i].caught {
                foods[i].y += foods[i].speed
            }
        }
        let beforeCount = foods.count
        foods.removeAll { $0.y > 800 && !$0.caught }
        let removed = beforeCount - foods.count
        missedCount += removed

        foods.removeAll { $0.caught && $0.y > -100 && $0.y < 900 ? false : $0.caught }
    }

    func notifyRecipesReady() {
        recipesReady = true
        withAnimation(.spring(duration: 0.5)) {
            showBanner = true
        }
    }
}

struct LoadingView: View {
    let recipesReady: Bool
    let onCancel: () -> Void
    let onShowRecipes: () -> Void
    @Environment(LanguageManager.self) private var lang

    @State private var game = FoodGameState()
    @State private var catchEffect: CGPoint?
    @State private var catchEmoji: String = ""
    @State private var spawnTimer: Timer?
    @State private var gameTimer: Timer?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ForEach(game.foods) { food in
                        if !food.caught {
                            Text(food.emoji)
                                .font(.system(size: food.size))
                                .position(x: food.x, y: food.y)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    if let pt = catchEffect {
                        Text(catchEmoji)
                            .font(.system(size: 50))
                            .position(x: pt.x, y: pt.y)
                            .transition(.scale.combined(with: .opacity))
                            .onAppear {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(400))
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        catchEffect = nil
                                    }
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    if game.catchFood(at: location) {
                        withAnimation(.spring(duration: 0.2)) {
                            catchEmoji = "✅"
                            catchEffect = location
                        }
                    }
                }
                .onAppear { startGame(width: geo.size.width) }
                .onDisappear { stopGame() }
            }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("🎯 Score", "🎯 Skor"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(game.score)")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 12))

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 12) {
                    Text(lang.t("Tap the falling food!", "Düşen yemekleri yakala!"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                                .opacity(game.score % 3 == i ? 1 : 0.3)
                        }
                    }

                    Text(lang.t("Our chef is preparing your recipes", "Şefimiz tariflerinizi hazırlıyor"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)

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

            if game.showBanner {
                VStack {
                    Spacer()
                        .frame(height: 80)

                    Button {
                        onShowRecipes()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.t("Recipes are ready!", "Tarifler hazır!"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(lang.t("Tap to view your recipes", "Tariflerini görmek için dokun"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .padding(16)
                        .background(.ultraThickMaterial)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .sensoryFeedback(.success, trigger: game.showBanner)

                    Spacer()
                }
            }
        }
        .onChange(of: recipesReady) { _, newValue in
            if newValue {
                game.notifyRecipesReady()
            }
        }
    }

    private func startGame(width: CGFloat) {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            Task { @MainActor in
                game.spawnFood(in: width)
            }
        }

        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            Task { @MainActor in
                game.tick()
            }
        }
    }

    private func stopGame() {
        spawnTimer?.invalidate()
        gameTimer?.invalidate()
        spawnTimer = nil
        gameTimer = nil
    }
}
