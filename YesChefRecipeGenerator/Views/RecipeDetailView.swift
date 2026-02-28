import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let viewModel: RecipeViewModel
    var onFinishCooking: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @State private var showCookingMode: Bool = false
    @State private var copied: Bool = false

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
        VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("Spices", "Baharatlar"), systemImage: "leaf.fill")
                .font(.headline)

            if !recipe.spices_common.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("Common (assume available)", "Yaygın (mevcut varsayılır)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(recipe.spices_common, id: \.self) { spice in
                            Text(spice)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.green.opacity(0.12))
                                .foregroundStyle(.green)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
            }

            if !recipe.spices_optional.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("Optional (may need to buy)", "Opsiyonel (almanız gerekebilir)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(recipe.spices_optional, id: \.self) { spice in
                            Text(spice)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.purple.opacity(0.12))
                                .foregroundStyle(.purple)
                                .clipShape(.rect(cornerRadius: 8))
                        }
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
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
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
