import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: RecipeViewModel
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        RecipeFlowContainerView(viewModel: viewModel)
            .onChange(of: lang.current) { _, newValue in
                viewModel.translateIfNeeded(to: newValue.rawValue)
            }
            .onAppear {
                viewModel.language = lang.current.rawValue
            }
    }
}

struct CuisineChipView: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let action: () -> Void
    @Environment(LanguageManager.self) private var lang

    private var displayName: String {
        switch cuisine {
        case .turkish: return lang.t("Turkish", "Türk")
        case .italian: return lang.t("Italian", "İtalyan")
        case .mexican: return lang.t("Mexican", "Meksika")
        case .asian: return lang.t("Asian", "Asya")
        case .french: return lang.t("French", "Fransız")
        case .mediterranean: return lang.t("Mediterranean", "Akdeniz")
        case .american: return lang.t("American", "Amerikan")
        case .indian: return lang.t("Indian", "Hint")
        case .japanese: return lang.t("Japanese", "Japon")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: cuisine.icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                Text(displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.1), .orange.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? .orange : .primary)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.5) : Color(.separator).opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? .orange.opacity(0.1) : .clear, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
