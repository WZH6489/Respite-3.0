import Foundation
import ActivityKit

enum StudyLiveActivityManager {
    static func startOrUpdate(
        phaseTitle: String,
        isRunning: Bool,
        remainingSeconds: Int,
        quote: String,
        progress: Double
    ) {
        guard #available(iOS 16.1, *) else {
            print("[StudyLiveActivity] Unsupported iOS version")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[StudyLiveActivity] Live Activities are disabled in system/app settings")
            return
        }

        Task {
            await startOrUpdateAsync(
                phaseTitle: phaseTitle,
                isRunning: isRunning,
                remainingSeconds: remainingSeconds,
                quote: quote,
                progress: progress
            )
        }
    }

    static func end() {
        guard #available(iOS 16.1, *) else { return }
        Task {
            for activity in Activity<StudyTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.1, *)
    private static func startOrUpdateAsync(
        phaseTitle: String,
        isRunning: Bool,
        remainingSeconds: Int,
        quote: String,
        progress: Double
    ) async {
        let state = StudyTimerAttributes.ContentState(
            phaseTitle: phaseTitle,
            isRunning: isRunning,
            remainingSeconds: max(0, remainingSeconds),
            endDate: isRunning ? Date().addingTimeInterval(TimeInterval(max(0, remainingSeconds))) : nil,
            quote: quote,
            progress: min(1.0, max(0.0, progress))
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if let existing = Activity<StudyTimerAttributes>.activities.first {
            await existing.update(content)
            print("[StudyLiveActivity] Updated existing activity")
            return
        }

        do {
            let attributes = StudyTimerAttributes(sessionTitle: "Study Session")
            _ = try Activity<StudyTimerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[StudyLiveActivity] Requested new activity")
        } catch {
            print("[StudyLiveActivity] Request failed: \(error.localizedDescription)")
        }
    }
}
