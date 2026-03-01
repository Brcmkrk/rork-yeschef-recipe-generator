import SwiftUI

struct CookingModeView: View {
    let recipe: Recipe
    var onFinishCooking: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @Environment(TriedRecipesStore.self) private var triedStore
    @State private var currentStep: Int = 0
    @State private var timers: [StepTimer] = []

    var body: some View {
        NavigationStack {
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang.t("Cooking Mode", "Pişirme Modu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("Done", "Bitti")) { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            }
            .onAppear { parseTimers() }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))

                Rectangle()
                    .fill(.orange)
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
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(currentStep + 1)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.orange)
                    .clipShape(Circle())

                Text(recipe.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(recipe.steps[currentStep])
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var timerSection: some View {
        let stepTimers = timers.filter { $0.stepIndex == currentStep }

        return Group {
            if !stepTimers.isEmpty {
                VStack(spacing: 12) {
                    ForEach(stepTimers) { timer in
                        TimerCardView(timer: timer)
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
                    .font(.subheadline.weight(.semibold))
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
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button {
                    triedStore.add(recipe)
                    dismiss()
                    onFinishCooking?()
                } label: {
                    Label(lang.t("Finish", "Bitir"), systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
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
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(recipe.steps[currentStep + 1])
                .font(.subheadline)
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
    }
}

@Observable
class StepTimer: Identifiable {
    let id = UUID()
    let stepIndex: Int
    let totalSeconds: Int
    var remainingSeconds: Int
    var isRunning: Bool = false
    var isComplete: Bool = false
    private var timerTask: Task<Void, Never>?

    init(stepIndex: Int, totalSeconds: Int) {
        self.stepIndex = stepIndex
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
    }

    var displayTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    func start() {
        guard !isRunning && remainingSeconds > 0 else { return }
        isRunning = true
        timerTask = Task { @MainActor in
            while remainingSeconds > 0 && isRunning {
                try? await Task.sleep(for: .seconds(1))
                guard isRunning else { break }
                remainingSeconds -= 1
            }
            if remainingSeconds == 0 {
                isComplete = true
                isRunning = false
            }
        }
    }

    func pause() {
        isRunning = false
        timerTask?.cancel()
    }

    func reset() {
        isRunning = false
        isComplete = false
        timerTask?.cancel()
        remainingSeconds = totalSeconds
    }
}

struct TimerCardView: View {
    let timer: StepTimer
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: timer.progress)
                .tint(timer.isComplete ? .green : .orange)

            HStack(spacing: 12) {
                if timer.isComplete {
                    Label(lang.t("Complete!", "Tamamlandı!"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else if timer.isRunning {
                    Button {
                        timer.pause()
                    } label: {
                        Label(lang.t("Pause", "Duraklat"), systemImage: "pause.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        timer.start()
                    } label: {
                        Label(lang.t("Start", "Başlat"), systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
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
                ? Color.green.opacity(0.08)
                : Color(.secondarySystemGroupedBackground)
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(timer.isComplete ? Color.green.opacity(0.3) : .clear, lineWidth: 1.5)
        )
        .sensoryFeedback(.success, trigger: timer.isComplete)
    }
}
