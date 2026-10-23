import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island UI for the rest timer.
/// The countdown uses `Text(timerInterval:)`, which the system animates without the app running.
struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenRestView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 28)
                        .frame(maxWidth: 90, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.exerciseName.map { "Next set · \($0)" } ?? context.attributes.workoutTitle)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        ProgressView(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(.white)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                countdown(context, size: 14)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
            }
            .keylineTint(.white)
        }
    }

    private func countdown(_ context: ActivityViewContext<RestTimerAttributes>, size: CGFloat) -> some View {
        Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.white)
    }
}

private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                    .font(.system(size: 36, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.workoutTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if let name = context.state.exerciseName {
                    Text("Next: \(name)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(18)
    }
}
