import ActivityKit
import WidgetKit
import SwiftUI

struct CookingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.recipeName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if context.state.totalSteps > 0 {
                                Text("Step \(context.state.stepNumber)/\(context.state.totalSteps)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTimerDisplay(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: timerProgress(context: context))
                        .tint(.orange)
                        .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            } compactTrailing: {
                if context.state.isRunning {
                    Text(timerInterval: Date.now...context.state.timerEndDate, countsDown: true)
                        .monospacedDigit()
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(minWidth: 44)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(formatTime(context.state.remainingSeconds))
                        .monospacedDigit()
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(minWidth: 44)
                }
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<CookingActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text(context.attributes.recipeName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if context.state.totalSteps > 0 {
                    Text("Step \(context.state.stepNumber) of \(context.state.totalSteps)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }

                ProgressView(value: timerProgress(context: context))
                    .tint(.orange)
                    .padding(.top, 2)
            }

            Spacer()

            lockScreenTimerDisplay(context: context)
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.9))
    }

    @ViewBuilder
    private func lockScreenTimerDisplay(context: ActivityViewContext<CookingActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: Date.now...context.state.timerEndDate, countsDown: true)
                .monospacedDigit()
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 70)
        } else if context.state.remainingSeconds == 0 {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
        } else {
            Text(formatTime(context.state.remainingSeconds))
                .monospacedDigit()
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(minWidth: 70)
        }
    }

    @ViewBuilder
    private func expandedTimerDisplay(context: ActivityViewContext<CookingActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: Date.now...context.state.timerEndDate, countsDown: true)
                .monospacedDigit()
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 60)
        } else if context.state.remainingSeconds == 0 {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else {
            Text(formatTime(context.state.remainingSeconds))
                .monospacedDigit()
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(minWidth: 60)
        }
    }

    private func timerProgress(context: ActivityViewContext<CookingActivityAttributes>) -> Double {
        let total = context.attributes.totalSeconds
        guard total > 0 else { return 0 }
        return 1.0 - Double(context.state.remainingSeconds) / Double(total)
    }

    private func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
