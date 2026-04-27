#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import ActivityKit

@available(iOSApplicationExtension 16.1, *)
struct StudyLiveActivityWidgetDefinition: Widget {
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Session Progress")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                        Spacer()
                        Text("\(Int(min(1.0, max(0.0, context.state.progress)) * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    ProgressView(value: min(1.0, max(0.0, context.state.progress)))
                        .tint(Color(red: 0.35, green: 0.78, blue: 0.56))
                }

                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.74))
                    Text(context.state.quote)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                }
            }
            .padding(12)
            .activityBackgroundTint(Color.white.opacity(0.12))
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
                        HStack {
                            Text("Session Progress")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(min(1.0, max(0.0, context.state.progress)) * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(1.0, max(0.0, context.state.progress)))
                            .tint(Color(red: 0.35, green: 0.78, blue: 0.56))
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
#endif
