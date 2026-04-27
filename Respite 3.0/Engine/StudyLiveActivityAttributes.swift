import Foundation
import ActivityKit

struct StudyTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var isRunning: Bool
        var remainingSeconds: Int
        var endDate: Date?
        var quote: String
        var progress: Double
    }

    var sessionTitle: String
}
