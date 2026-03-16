import SwiftUI

struct CuisineSelectionView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Cuisine.allCases) { cuisine in
                        CuisineCardView(
                            cuisine: cuisine,
                            isSelected: viewModel.selectedCuisine == cuisine,
                            lang: lang
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                if viewModel.selectedCuisine == cuisine {
                                    viewModel.selectedCuisine = nil
                                } else {
                                    viewModel.selectedCuisine = cuisine
                                }
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

            Text(lang.t("Pick your cuisine", "Mutfak seç"))
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(lang.t("What kind of food are you craving?", "Ne tür bir yemek istiyorsun?"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
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
