import ActivityKit
import WidgetKit
import SwiftUI

private enum LiveWidgetAppearance {
    static let appGroupID = "group.com.stormforge.Respite-3-0"
    static let colorIntensityKey = "dev.ui.colorIntensity"

    static func progressTint() -> Color {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let raw = defaults.object(forKey: colorIntensityKey) as? Double ?? 0.85
        let intensity = min(1.40, max(0.35, raw))
        let normalized = (intensity - 0.35) / (1.40 - 0.35)
        let safe = min(1.0, max(0.0, normalized))
        return Color(
            red: 0.44 + (0.16 * safe),
            green: 0.67 + (0.14 * safe),
            blue: 0.86 + (0.10 * safe)
        )
    }
}

struct StudyLiveWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(context.state.phaseTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Session Progress")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                }

                if let endDate = context.state.endDate, context.state.isRunning {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.white)
                } else {
                    Text(shortTime(context.state.remainingSeconds))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.white)
                }

                ProgressView(value: min(1.0, max(0.0, context.state.progress)))
                    .tint(LiveWidgetAppearance.progressTint())

                Text(context.state.quote)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }
            .padding(12)
            .activityBackgroundTint(Color.white.opacity(0.12))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.phaseTitle)
                        .font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let endDate = context.state.endDate, context.state.isRunning {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.body.monospacedDigit())
                    } else {
                        Text(shortTime(context.state.remainingSeconds))
                            .font(.body.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: min(1.0, max(0.0, context.state.progress)))
                            .tint(LiveWidgetAppearance.progressTint())
                        Text("Session Progress")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.quote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text("Focus")
                    .font(.caption2.bold())
            } compactTrailing: {
                if let endDate = context.state.endDate, context.state.isRunning {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.caption2.monospacedDigit())
                } else {
                    Text(shortTime(context.state.remainingSeconds))
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func shortTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return "\(minutes)m"
    }
}
