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
            LinearGradient(
                colors: [Color(red: 1, green: 0.97, blue: 0.93), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(.capsule)
                            .position(x: pt.x, y: pt.y - 20)
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
                        let pops = ["+1", "yum!", "nice!", "got it!"]
                        withAnimation(.spring(duration: 0.2)) {
                            catchEmoji = pops.randomElement() ?? "+1"
                            catchEffect = location
                        }
                    }
                }
                .onAppear { startGame(width: geo.size.width) }
                .onDisappear { stopGame() }
            }

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text("\(game.score)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 14))

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
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                                .opacity(game.score % 3 == i ? 1 : 0.3)
                        }
                    }

                    Text(lang.t("Cooktopus is preparing your recipes", "Cooktopus tariflerinizi hazırlıyor"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)

                VStack(spacing: 6) {
                    Image("MascotImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .opacity(0.6)
                    Text("Cooktopus")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 32)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if game.showBanner {
                            onShowRecipes()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(game.showBanner ? Color.green : Color(.systemGray4))
                                .frame(width: 64, height: 64)
                                .shadow(color: game.showBanner ? .green.opacity(0.5) : .black.opacity(0.1), radius: game.showBanner ? 12 : 4, y: 2)

                            if game.showBanner {
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(.white)
                                    .shadow(color: .white.opacity(0.8), radius: 6)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .animation(.spring(duration: 0.5, bounce: 0.3), value: game.showBanner)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: game.showBanner)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
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
