import SwiftUI

struct CuisineSelectionView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                selectAllButtons

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Cuisine.allCases) { cuisine in
                        CuisineCardView(
                            cuisine: cuisine,
                            isSelected: viewModel.selectedCuisines.contains(cuisine),
                            lang: lang
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.toggleCuisine(cuisine)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 44))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 4)

            Text(lang.t("Pick your cuisine(s)", "Mutfak(ları) seç"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t("Select one or more cuisines", "Bir veya daha fazla mutfak seç"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var selectAllButtons: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.selectAllCuisines()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text(lang.t("Select All", "Tümünü Seç"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.clearCuisines()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                    Text(lang.t("Deselect All", "Tümünü Kaldır"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color(.tertiarySystemFill))
                .foregroundStyle(.secondary)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}

struct CuisineCardView: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let lang: LanguageManager
    let action: () -> Void

    private var displayName: String {
        cuisine.localizedName(language: lang.current.rawValue)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange.opacity(0.15) : Color(.tertiarySystemFill))
                        .frame(width: 52, height: 52)

                    Image(systemName: cuisine.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .orange : .secondary)
                }

                Text(displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isSelected ? .orange : .primary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.06), .orange.opacity(0.12)],
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
                        isSelected ? Color.orange.opacity(0.5) : Color(.separator).opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: isSelected ? .orange.opacity(0.12) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
