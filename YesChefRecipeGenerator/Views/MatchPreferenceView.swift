import SwiftUI

struct MatchPreferenceView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                matchOptions
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

            Text(lang.t("Recipe matching", "Tarif eşleştirme"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t("How closely should recipes match your ingredients?", "Tarifler malzemelerinle ne kadar uyumlu olsun?"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var matchOptions: some View {
        VStack(spacing: 12) {
            matchCard(
                isStrict: true,
                icon: "checkmark.seal.fill",
                iconColor: .green,
                title: lang.t("Strict Match", "Tam Eşleşme"),
                description: lang.t(
                    "Only recipes that use your exact ingredients. No surprises, no extras needed.",
                    "Sadece senin malzemelerini kullanan tarifler. Sürpriz yok, ekstra malzeme yok."
                ),
                isSelected: viewModel.useStrictMatch
            )

            matchCard(
                isStrict: false,
                icon: "sparkles",
                iconColor: .purple,
                title: lang.t("Flexible Match", "Esnek Eşleşme"),
                description: lang.t(
                    "Recipes mostly using your ingredients, but may suggest extras for better results.",
                    "Çoğunlukla senin malzemelerini kullanan tarifler, ama daha iyi sonuçlar için ekstra önerebilir."
                ),
                isSelected: !viewModel.useStrictMatch
            )
        }
    }

    private func matchCard(isStrict: Bool, icon: String, iconColor: Color, title: String, description: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.useStrictMatch = isStrict
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? iconColor.opacity(0.15) : Color(.tertiarySystemFill))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? iconColor : .secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : Color(.tertiaryLabel))
                    .padding(.top, 2)
            }
            .padding(16)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.04), .orange.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Color.orange.opacity(0.4) : Color(.separator).opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: isSelected ? .orange.opacity(0.08) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
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
                    label: lang.t("Cuisine", "Mutfak"),
                    value: viewModel.selectedCuisine?.localizedName(language: lang.current.rawValue) ?? "-"
                )
                summaryRow(
                    icon: "person.2.fill",
                    label: lang.t("Servings", "Porsiyon"),
                    value: "\(viewModel.servings)"
                )
                summaryRow(
                    icon: "slider.horizontal.3",
                    label: lang.t("Match", "Eşleşme"),
                    value: viewModel.useStrictMatch
                        ? lang.t("Strict", "Tam")
                        : lang.t("Flexible", "Esnek")
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
        }
    }
}
