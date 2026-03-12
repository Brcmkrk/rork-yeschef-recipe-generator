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
                                .lineLimit(1)
                            if context.state.totalSteps > 0 {
                                Text("Step \(context.state.stepNumber)/\(context.state.totalSteps)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerDisplay(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: timerProgress(context: context))
                        .tint(.orange)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } compactTrailing: {
                if context.state.isRunning {
                    Text(context.state.timerEndDate, style: .timer)
                        .monospacedDigit()
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(minWidth: 36)
                } else {
                    Text(formatTime(context.state.remainingSeconds))
                        .monospacedDigit()
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 36)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text(context.attributes.recipeName)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                }

                if context.state.totalSteps > 0 {
                    Text("Step \(context.state.stepNumber) of \(context.state.totalSteps)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: timerProgress(context: context))
                    .tint(.orange)
                    .padding(.top, 4)
            }

            Spacer()

            timerDisplay(context: context)
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.85))
    }

    @ViewBuilder
    private func timerDisplay(context: ActivityViewContext<CookingActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(context.state.timerEndDate, style: .timer)
                .monospacedDigit()
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
        } else if context.state.remainingSeconds == 0 {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else {
            Text(formatTime(context.state.remainingSeconds))
                .monospacedDigit()
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
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
