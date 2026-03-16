import SwiftUI

struct ServingSelectionView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                servingCounter
                presetGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(.purple.gradient)
                .padding(.bottom, 4)

            Text(lang.t("How many servings?", "Kaç porsiyon?"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t("Choose the number of portions", "Porsiyon sayısını seç"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var servingCounter: some View {
        HStack(spacing: 32) {
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    if viewModel.servings > 1 {
                        viewModel.servings -= 1
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(viewModel.servings > 1 ? .orange : .secondary.opacity(0.4))
                    .frame(width: 56, height: 56)
                    .background(
                        viewModel.servings > 1
                            ? Color.orange.opacity(0.1)
                            : Color(.tertiarySystemFill)
                    )
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.servings <= 1)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.servings)

            VStack(spacing: 4) {
                Text("\(viewModel.servings)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(viewModel.servings)))
                    .animation(.spring(duration: 0.3), value: viewModel.servings)

                Text(lang.t(viewModel.servings == 1 ? "serving" : "servings", viewModel.servings == 1 ? "porsiyon" : "porsiyon"))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    if viewModel.servings < 10 {
                        viewModel.servings += 1
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(viewModel.servings < 10 ? .orange : .secondary.opacity(0.4))
                    .frame(width: 56, height: 56)
                    .background(
                        viewModel.servings < 10
                            ? Color.orange.opacity(0.1)
                            : Color(.tertiarySystemFill)
                    )
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.servings >= 10)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.servings)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("Quick select", "Hızlı seç"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach([1, 2, 4, 6, 8], id: \.self) { count in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.servings = count
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Image(systemName: servingIcon(for: count))
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            viewModel.servings == count
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(viewModel.servings == count ? .white : .primary)
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(
                            color: viewModel.servings == count ? .orange.opacity(0.25) : .clear,
                            radius: 6, y: 2
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: viewModel.servings)
                }
            }
        }
    }

    private func servingIcon(for count: Int) -> String {
        switch count {
        case 1: return "person.fill"
        case 2: return "person.2.fill"
        case 4: return "person.3.fill"
        default: return "person.3.fill"
        }
    }
}
