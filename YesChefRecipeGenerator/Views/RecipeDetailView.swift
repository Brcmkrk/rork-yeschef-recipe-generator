import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let viewModel: RecipeViewModel
    var onFinishCooking: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @State private var showCookingMode: Bool = false
    @State private var copied: Bool = false
    @State private var expandedSpice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    ingredientsCard
                    spicesCard
                    if !recipe.required_extra_ingredients.isEmpty {
                        extraIngredientsCard
                    }
                    stepsCard
                    actionButtons
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                CookingModeView(recipe: recipe) {
                    dismiss()
                    onFinishCooking?()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(recipe.title)
                .font(.title2.weight(.bold))

            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                badge(recipe.cuisine, icon: "globe", color: .orange)
                badge(recipe.difficulty, icon: "chart.bar.fill", color: difficultyColor)
                badge("\(recipe.calories) cal", icon: "flame.fill", color: .red)
                badge("\(recipe.servings) srv", icon: "person.2.fill", color: .blue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("Ingredients", "Malzemeler"), systemImage: "cart.fill")
                .font(.headline)

            ForEach(recipe.ingredients) { ingredient in
                HStack {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text(ingredient.name)
                        .font(.body)
                    Spacer()
                    Text("\(ingredient.quantity) \(ingredient.unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var spicesCard: some View {
        let spices = recipe.allSpices

        return VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("Spices", "Baharatlar"), systemImage: "leaf.fill")
                .font(.headline)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var extraIngredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.t("Extra Ingredients Needed", "Gerekli Ekstra Malzemeler"), systemImage: "bag.fill")
                .font(.headline)
                .foregroundStyle(.purple)

            FlowLayout(spacing: 6) {
                ForEach(recipe.required_extra_ingredients, id: \.self) { item in
                    Text(item)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("Steps", "Adımlar"), systemImage: "list.number")
                .font(.headline)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.orange)
                        .clipShape(Circle())

                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var actionButtons: some View {
        Button {
            showCookingMode = true
        } label: {
            Label(lang.t("Start Cooking Mode", "Pişirme Modunu Başlat"), systemImage: "flame.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    private var difficultyColor: Color {
        switch recipe.difficulty.lowercased() {
        case "easy", "kolay": return .green
        case "medium", "orta": return .orange
        case "hard", "zor": return .red
        default: return .secondary
        }
    }

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(.rect(cornerRadius: 8))
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
                        .font(.subheadline.weight(.medium))
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
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.12))
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
