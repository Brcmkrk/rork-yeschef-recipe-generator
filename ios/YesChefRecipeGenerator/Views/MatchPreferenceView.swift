import SwiftUI

struct MatchPreferenceView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    private let ratios: [(exact: Int, extra: Int)] = [
        (4, 0), (3, 1), (2, 2), (1, 3), (0, 4)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                ratioCards
                summaryCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 44))
                .foregroundStyle(.mint.gradient)
                .padding(.bottom, 4)

            Text(lang.t("Recipe Match", "Tarif Eşleşme"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t(
                "Choose how many recipes should match your ingredients exactly vs. creatively",
                "Kaç tarifin malzemelerinle birebir, kaçının yaratıcı olacağını seç"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var ratioCards: some View {
        VStack(spacing: 10) {
            ForEach(ratios, id: \.exact) { ratio in
                let isSelected = viewModel.exactMatchCount == ratio.exact && viewModel.extraIngredientCount == ratio.extra

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.exactMatchCount = ratio.exact
                        viewModel.extraIngredientCount = ratio.extra
                    }
                } label: {
                    HStack(spacing: 14) {
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { i in
                                Circle()
                                    .fill(i < ratio.exact ? Color.green : Color.purple)
                                    .frame(width: 12, height: 12)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ratioTitle(ratio))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(ratioDescription(ratio))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .orange : Color(.tertiaryLabel))
                    }
                    .padding(14)
                    .background(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [.orange.opacity(0.04), .orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.orange.opacity(0.4) : Color(.separator).opacity(0.15),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .shadow(color: isSelected ? .orange.opacity(0.08) : .clear, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
            }
        }
    }

    private func ratioTitle(_ ratio: (exact: Int, extra: Int)) -> String {
        if ratio.extra == 0 {
            return lang.t("\(ratio.exact) Exact Match", "\(ratio.exact) Tam Eşleşme")
        } else if ratio.exact == 0 {
            return lang.t("\(ratio.extra) Creative", "\(ratio.extra) Yaratıcı")
        } else {
            return lang.t("\(ratio.exact) Exact · \(ratio.extra) Creative", "\(ratio.exact) Tam · \(ratio.extra) Yaratıcı")
        }
    }

    private func ratioDescription(_ ratio: (exact: Int, extra: Int)) -> String {
        if ratio.extra == 0 {
            return lang.t("Only recipes using your exact ingredients", "Sadece malzemelerinle yapılan tarifler")
        } else if ratio.exact == 0 {
            return lang.t("Creative recipes that may need extra ingredients", "Ekstra malzeme gerektirebilen yaratıcı tarifler")
        } else {
            return lang.t(
                "\(ratio.exact) using your ingredients, \(ratio.extra) with extras",
                "\(ratio.exact) malzemelerinle, \(ratio.extra) ekstralarla"
            )
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.badge.checkmark")
                    .foregroundStyle(.orange)
                Text(lang.t("Summary", "Özet"))
                    .font(.system(.headline, design: .rounded))
            }

            VStack(spacing: 8) {
                summaryRow(
                    icon: "carrot.fill",
                    label: lang.t("Ingredients", "Malzemeler"),
                    value: "\(viewModel.selectedIngredients.count) \(lang.t("items", "adet"))"
                )
                summaryRow(
                    icon: "globe",
                    label: lang.t("Cuisines", "Mutfaklar"),
                    value: viewModel.selectedCuisines.isEmpty
                        ? "-"
                        : viewModel.selectedCuisines.map { $0.localizedName(language: lang.current.rawValue) }.joined(separator: ", ")
                )
                summaryRow(
                    icon: "person.2.fill",
                    label: lang.t("Servings", "Porsiyon"),
                    value: "\(viewModel.servings)"
                )
                summaryRow(
                    icon: "slider.horizontal.3",
                    label: lang.t("Match", "Eşleşme"),
                    value: "\(viewModel.exactMatchCount) \(lang.t("exact", "tam")) · \(viewModel.extraIngredientCount) \(lang.t("creative", "yaratıcı"))"
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
    }
}
