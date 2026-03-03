import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(LikesStore.self) private var likesStore
    @Environment(TriedRecipesStore.self) private var triedStore
    @State private var showLanguagePicker: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack {
                            Label {
                                Text(lang.t("Language", "Dil"))
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "globe")
                                    .foregroundStyle(.blue)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Text(lang.current.flag)
                                Text(lang.current.displayName)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(lang.t("General", "Genel"))
                }

                Section {
                    HStack {
                        Label {
                            Text(lang.t("Version", "Sürüm"))
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text(lang.t("About", "Hakkında"))
                }
            }
            .navigationTitle(lang.t("Settings", "Ayarlar"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showLanguagePicker) {
                languageSheet
            }
            .onChange(of: lang.current) { _, newValue in
                likesStore.translateRecipes(to: newValue.rawValue)
                triedStore.translateRecipes(to: newValue.rawValue)
            }
        }
    }

    private var languageSheet: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            lang.current = language
                        }
                        showLanguagePicker = false
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.title2)

                            Text(language.displayName)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            if lang.current == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                    .symbolEffect(.bounce, value: lang.current)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(lang.t("Language", "Dil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("Done", "Tamam")) {
                        showLanguagePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
