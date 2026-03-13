import SwiftUI
import ActivityKit

struct CookingModeView: View {
    let recipe: Recipe
    var onFinishCooking: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @Environment(TriedRecipesStore.self) private var triedStore
    @State private var currentStep: Int = 0
    @State private var timers: [StepTimer] = []
    @State private var showPostRating: Bool = false
    @State private var showReturnConfirmation: Bool = false
    @State private var showMenuConfirmation: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    private var isFreeTier: Bool {
        !SubscriptionManager.shared.isProUser
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    progressBar

                    ScrollView {
                        VStack(spacing: 24) {
                            stepCounter
                            currentStepCard
                            timerSection
                            navigationButtons
                            if currentStep < recipe.steps.count - 1 {
                                nextStepPreview
                            }
                        }
                        .padding(16)
                    }

                    Spacer(minLength: 0)
                }

                if showPostRating {
                    PostCookingRatingView(
                        recipe: recipe,
                        onReturnToRecipes: {
                            dismiss()
                        },
                        onGoToMenu: {
                            dismiss()
                            onFinishCooking?()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.02), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(lang.t("Cooking Mode", "Pişirme Modu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showReturnConfirmation = true
                    } label: {
                        Image(systemName: "arrow.uturn.left")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.orange)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMenuConfirmation = true
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.orange)
                }
            }
            .alert(
                lang.t("Are you sure?", "Emin misin?"),
                isPresented: $showReturnConfirmation
            ) {
                Button(lang.t("Yes, Return", "Evet, Dön"), role: .destructive) {
                    endAllLiveActivities()
                    dismiss()
                }
                Button(lang.t("Cancel", "İptal"), role: .cancel) {}
            } message: {
                if isFreeTier {
                    Text(lang.t(
                        "Your free recipe has already been counted. Are you sure you want to leave?",
                        "Ücretsiz tarifin zaten sayıldı. Çıkmak istediğine emin misin?"
                    ))
                } else {
                    Text(lang.t("You'll return to the recipes.", "Tariflere döneceksin."))
                }
            }
            .alert(
                lang.t("Are you sure?", "Emin misin?"),
                isPresented: $showMenuConfirmation
            ) {
                Button(lang.t("Go to Menu", "Ana Menüye Git"), role: .destructive) {
                    endAllLiveActivities()
                    dismiss()
                    onFinishCooking?()
                }
                Button(lang.t("Cancel", "İptal"), role: .cancel) {}
            } message: {
                if isFreeTier {
                    Text(lang.t(
                        "Your free recipe has already been counted. Are you sure you want to leave?",
                        "Ücretsiz tarifin zaten sayıldı. Çıkmak istediğine emin misin?"
                    ))
                } else {
                    Text(lang.t("You'll return to the main menu.", "Ana menüye döneceksin."))
                }
            }
            .onAppear { parseTimers() }
            .onDisappear { saveTimerStates() }
            .onChange(of: scenePhase) { oldValue, newValue in
                if newValue == .background {
                    saveTimerStates()
                } else if newValue == .active && oldValue == .background {
                    for timer in timers where timer.isRunning {
                        timer.recalculateFromSavedState(recipeId: recipe.id)
                    }
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.4, blue: 0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(duration: 0.4), value: currentStep)
            }
        }
        .frame(height: 4)
    }

    private var progress: CGFloat {
        guard recipe.steps.count > 1 else { return 1 }
        return CGFloat(currentStep + 1) / CGFloat(recipe.steps.count)
    }

    private var stepCounter: some View {
        Text(lang.t(
            "Step \(currentStep + 1) of \(recipe.steps.count)",
            "Adım \(currentStep + 1) / \(recipe.steps.count)"
        ))
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(currentStep + 1)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.85, green: 0.4, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)

                Text(recipe.title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(recipe.steps[currentStep])
                .font(.system(.title3, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.orange.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var timerSection: some View {
        let stepTimers = timers.filter { $0.stepIndex == currentStep }

        return Group {
            if !stepTimers.isEmpty {
                VStack(spacing: 12) {
                    ForEach(stepTimers) { timer in
                        TimerCardView(
                            timer: timer,
                            recipeName: recipe.title,
                            currentStep: currentStep,
                            totalSteps: recipe.steps.count
                        )
                    }
                }
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    currentStep = max(0, currentStep - 1)
                }
            } label: {
                Label(lang.t("Previous", "Önceki"), systemImage: "chevron.left")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .disabled(currentStep == 0)

            if currentStep < recipe.steps.count - 1 {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        currentStep += 1
                    }
                } label: {
                    Label(lang.t("Next", "Sonraki"), systemImage: "chevron.right")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button {
                    triedStore.add(recipe)
                    endAllLiveActivities()
                    withAnimation(.spring(duration: 0.4)) {
                        showPostRating = true
                    }
                } label: {
                    Label(lang.t("Finish", "Bitir"), systemImage: "checkmark")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .sensoryFeedback(.selection, trigger: currentStep)
    }

    private var nextStepPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("UP NEXT", "SIRADA"))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)

            Text(recipe.steps[currentStep + 1])
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func parseTimers() {
        let minutePattern = /(\d+)\s*(?:minutes?|mins?|min|dakika|dk)/
        let hourPattern = /(\d+)\s*(?:hours?|hrs?|hr|saat)/
        let secondPattern = /(\d+)\s*(?:seconds?|secs?|sec|saniye|sn)/
        for (index, step) in recipe.steps.enumerated() {
            let lowered = step.lowercased()
            for match in lowered.matches(of: minutePattern) {
                if let minutes = Int(match.1), minutes > 0 {
                    timers.append(StepTimer(stepIndex: index, totalSeconds: minutes * 60))
                }
            }
            for match in lowered.matches(of: hourPattern) {
                if let hours = Int(match.1), hours > 0 {
                    timers.append(StepTimer(stepIndex: index, totalSeconds: hours * 3600))
                }
            }
            for match in lowered.matches(of: secondPattern) {
                if let seconds = Int(match.1), seconds > 0 {
                    timers.append(StepTimer(stepIndex: index, totalSeconds: seconds))
                }
            }
        }
        restoreTimerStates()
    }

    private func saveTimerStates() {
        for timer in timers {
            timer.saveState(recipeId: recipe.id)
        }
    }

    private func restoreTimerStates() {
        for timer in timers {
            timer.restoreState(recipeId: recipe.id)
        }
    }

    private func endAllLiveActivities() {
        for timer in timers {
            timer.endLiveActivity()
            timer.clearSavedState(recipeId: recipe.id)
        }
    }
}

@Observable
class StepTimer: Identifiable {
    let id: UUID
    let stepIndex: Int
    let totalSeconds: Int
    var remainingSeconds: Int
    var isRunning: Bool = false
    var isComplete: Bool = false
    private var timerTask: Task<Void, Never>?
    private var startDate: Date?
    private var activity: Activity<CookingActivityAttributes>?
    private var liveActivityRecipeName: String = ""
    private var liveActivityStepNumber: Int = 0
    private var liveActivityTotalSteps: Int = 0

    init(stepIndex: Int, totalSeconds: Int) {
        self.id = UUID()
        self.stepIndex = stepIndex
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
    }

    var displayTime: String {
        let hrs = remainingSeconds / 3600
        let mins = (remainingSeconds % 3600) / 60
        let secs = remainingSeconds % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    func start() {
        guard !isRunning && remainingSeconds > 0 else { return }
        isRunning = true
        startDate = Date()
        timerTask = Task { @MainActor in
            while remainingSeconds > 0 && isRunning {
                try? await Task.sleep(for: .seconds(1))
                guard isRunning else { break }
                remainingSeconds -= 1
                updateLiveActivity()
            }
            if remainingSeconds == 0 {
                isComplete = true
                isRunning = false
                endLiveActivity()
            }
        }
    }

    func pause() {
        isRunning = false
        startDate = nil
        timerTask?.cancel()
        updateLiveActivity()
    }

    func reset() {
        isRunning = false
        isComplete = false
        startDate = nil
        timerTask?.cancel()
        remainingSeconds = totalSeconds
        endLiveActivity()
    }

    func saveState(recipeId: String) {
        let key = "timer_\(recipeId)_\(stepIndex)_\(totalSeconds)"
        if isRunning, let startDate {
            let elapsed = Int(Date().timeIntervalSince(startDate))
            let saved = remainingSeconds
            UserDefaults.standard.set(saved, forKey: "\(key)_remaining")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(key)_savedAt")
            UserDefaults.standard.set(true, forKey: "\(key)_wasRunning")
            _ = elapsed
        } else if remainingSeconds < totalSeconds {
            UserDefaults.standard.set(remainingSeconds, forKey: "\(key)_remaining")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(key)_savedAt")
            UserDefaults.standard.set(false, forKey: "\(key)_wasRunning")
        }
        UserDefaults.standard.set(isComplete, forKey: "\(key)_complete")
    }

    func restoreState(recipeId: String) {
        let key = "timer_\(recipeId)_\(stepIndex)_\(totalSeconds)"
        let savedRemaining = UserDefaults.standard.integer(forKey: "\(key)_remaining")
        let savedAt = UserDefaults.standard.double(forKey: "\(key)_savedAt")
        let wasRunning = UserDefaults.standard.bool(forKey: "\(key)_wasRunning")
        let wasComplete = UserDefaults.standard.bool(forKey: "\(key)_complete")

        guard savedAt > 0 else { return }

        if wasComplete {
            remainingSeconds = 0
            isComplete = true
            isRunning = false
            return
        }

        if wasRunning {
            let elapsed = Int(Date().timeIntervalSince1970 - savedAt)
            let newRemaining = max(0, savedRemaining - elapsed)
            remainingSeconds = newRemaining
            if newRemaining == 0 {
                isComplete = true
                isRunning = false
            } else {
                start()
            }
        } else if savedRemaining > 0 && savedRemaining < totalSeconds {
            remainingSeconds = savedRemaining
        }
    }

    func recalculateFromSavedState(recipeId: String) {
        let key = "timer_\(recipeId)_\(stepIndex)_\(totalSeconds)"
        let savedRemaining = UserDefaults.standard.integer(forKey: "\(key)_remaining")
        let savedAt = UserDefaults.standard.double(forKey: "\(key)_savedAt")
        let wasRunning = UserDefaults.standard.bool(forKey: "\(key)_wasRunning")
        guard savedAt > 0, wasRunning else { return }
        let elapsed = Int(Date().timeIntervalSince1970 - savedAt)
        let newRemaining = max(0, savedRemaining - elapsed)
        remainingSeconds = newRemaining
        if newRemaining == 0 {
            isComplete = true
            isRunning = false
            timerTask?.cancel()
            endLiveActivity()
        }
    }

    func clearSavedState(recipeId: String) {
        let key = "timer_\(recipeId)_\(stepIndex)_\(totalSeconds)"
        UserDefaults.standard.removeObject(forKey: "\(key)_remaining")
        UserDefaults.standard.removeObject(forKey: "\(key)_savedAt")
        UserDefaults.standard.removeObject(forKey: "\(key)_wasRunning")
        UserDefaults.standard.removeObject(forKey: "\(key)_complete")
    }

    func startLiveActivity(recipeName: String, stepNumber: Int, totalSteps: Int) {
        liveActivityRecipeName = recipeName
        liveActivityStepNumber = stepNumber
        liveActivityTotalSteps = totalSteps

        guard activity == nil else {
            updateLiveActivity()
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }

        let attributes = CookingActivityAttributes(
            recipeName: recipeName,
            totalSeconds: totalSeconds
        )
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = CookingActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerEndDate: endDate,
            isRunning: isRunning,
            stepNumber: stepNumber,
            totalSteps: totalSteps
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate.addingTimeInterval(60)),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateLiveActivity() {
        guard let activity else { return }
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = CookingActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerEndDate: endDate,
            isRunning: isRunning,
            stepNumber: liveActivityStepNumber,
            totalSteps: liveActivityTotalSteps
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endLiveActivity() {
        guard let activity else { return }
        let finalState = CookingActivityAttributes.ContentState(
            remainingSeconds: 0,
            timerEndDate: Date(),
            isRunning: false,
            stepNumber: liveActivityStepNumber,
            totalSteps: liveActivityTotalSteps
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}

struct TimerCardView: View {
    let timer: StepTimer
    let recipeName: String
    let currentStep: Int
    let totalSteps: Int
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(timer.isComplete ? lang.t("Time's up!", "Süre doldu!") : timer.displayTime)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(timer.isComplete ? .green : .primary)

                Spacer()

                Text("\(timer.totalSeconds / 60) min")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: timer.progress)
                .tint(timer.isComplete ? .green : .orange)

            HStack(spacing: 12) {
                if timer.isComplete {
                    Label(lang.t("Complete!", "Tamamlandı!"), systemImage: "checkmark.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                } else if timer.isRunning {
                    Button {
                        timer.pause()
                    } label: {
                        Label(lang.t("Pause", "Duraklat"), systemImage: "pause.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        timer.start()
                        timer.startLiveActivity(
                            recipeName: recipeName,
                            stepNumber: currentStep + 1,
                            totalSteps: totalSteps
                        )
                    } label: {
                        Label(lang.t("Start", "Başlat"), systemImage: "play.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(timer.remainingSeconds == timer.totalSeconds && !timer.isComplete)
            }
        }
        .padding(16)
        .background(
            timer.isComplete
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.04), .green.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(timer.isComplete ? Color.green.opacity(0.3) : .clear, lineWidth: 1.5)
        )
        .sensoryFeedback(.success, trigger: timer.isComplete)
    }
}
