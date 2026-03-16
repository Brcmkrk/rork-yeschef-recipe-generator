import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let viewModel: RecipeViewModel
    var isExpanding: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @State private var showCookingMode: Bool = false
    @State private var copied: Bool = false
    @State private var expandedSpice: String?
    @Environment(FreeRecipeTracker.self) private var freeRecipeTracker
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    quickStatsBar
                    ingredientsCard

                    if recipe.isFullyLoaded {
                        spicesCard
                        if !recipe.required_extra_ingredients.isEmpty {
                            extraIngredientsCard
                        }
                        stepsCard
                        actionButtons
                    } else {
                        loadingDetailsCard
                    }
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.02), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if recipe.isFullyLoaded {
                        Button {
                            UIPasteboard.general.string = viewModel.copyRecipeText(recipe)
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .contentTransition(.symbolEffect(.replace))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCookingMode) {
                CookingModeView(recipe: recipe, viewModel: viewModel)
            }
            .onChange(of: viewModel.shouldReturnToHome) { _, newValue in
                if newValue {
                    showCookingMode = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.orange.opacity(0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 18))
    }

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            statPill(recipe.cuisine, icon: "globe", color: .orange)
            Spacer()
            statPill(recipe.difficulty, icon: "chart.bar.fill", color: difficultyColor)
            Spacer()
            statPill("\(recipe.calories) cal", icon: "flame.fill", color: .red)
            Spacer()
            statPill("\(recipe.servings) srv", icon: "person.2.fill", color: .blue)
        }
        .padding(.horizontal, 4)
    }

    private func statPill(_ text: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .foregroundStyle(.orange)
                Text(lang.t("Ingredients", "Malzemeler"))
                    .font(.system(.headline, design: .rounded))
            }

            ForEach(recipe.ingredients) { ingredient in
                HStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 6, height: 6)
                    Text(ingredient.name)
                        .font(.body)
                    Spacer()
                    Text("\(ingredient.quantity) \(ingredient.unit)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var loadingDetailsCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.08))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(.orange.opacity(0.04))
                    .frame(width: 100, height: 100)

                Image("MascotImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }

            VStack(spacing: 8) {
                Text(lang.t("Your recipe is being prepared", "Tarifiniz hazırlanıyor"))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)

                Text(lang.t(
                    "Cooktopus is writing the detailed steps for you",
                    "Cooktopus sizin için detaylı adımları yazıyor"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            ProgressView()
                .controlSize(.regular)
                .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var spicesCard: some View {
        let spices = recipe.allSpices

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text(lang.t("Spices", "Baharatlar"))
                    .font(.system(.headline, design: .rounded))
            }

            if spices.isEmpty {
                Text(lang.t("No spices needed", "Baharat gerekmiyor"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(lang.t("Tap a spice to see alternatives", "Alternatifler için baharata dokun"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 8) {
                    ForEach(spices) { spice in
                        SpiceRow(
                            spice: spice,
                            isExpanded: expandedSpice == spice.name,
                            onTap: {
                                withAnimation(.spring(duration: 0.3)) {
                                    if expandedSpice == spice.name {
                                        expandedSpice = nil
                                    } else {
                                        expandedSpice = spice.name
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var extraIngredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .foregroundStyle(.purple)
                Text(lang.t("Extra Ingredients Needed", "Gerekli Ekstra Malzemeler"))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.purple)
            }

            FlowLayout(spacing: 6) {
                ForEach(recipe.required_extra_ingredients, id: \.self) { item in
                    Text(item)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .foregroundStyle(.blue)
                Text(lang.t("Steps", "Adımlar"))
                    .font(.system(.headline, design: .rounded))
            }

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.85, green: 0.4, blue: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())

                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var actionButtons: some View {
        Button {
            if !subscriptionManager.isProUser {
                freeRecipeTracker.incrementUsage()
            }
            showCookingMode = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                Text(lang.t("Start Cooking Mode", "Pişirme Modunu Başlat"))
                    .font(.system(.headline, design: .rounded))
            }
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
            .shadow(color: .orange.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: showCookingMode)
    }

    private var difficultyColor: Color {
        switch recipe.difficulty.lowercased() {
        case "easy", "kolay": return .green
        case "medium", "orta": return .orange
        case "hard", "zor": return .red
        default: return .secondary
        }
    }
}

struct SpiceRow: View {
    let spice: RecipeSpice
    let isExpanded: Bool
    let onTap: () -> Void
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Text(spice.name)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    if !spice.alternatives.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(isExpanded ? Color.green.opacity(0.06) : .clear)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if isExpanded && !spice.alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("Can be replaced with:", "Yerine kullanılabilir:"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 34)

                    FlowLayout(spacing: 6) {
                        ForEach(spice.alternatives, id: \.self) { alt in
                            Text(alt)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .padding(.leading, 34)
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
