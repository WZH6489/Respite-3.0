import Foundation
import Combine

/// Manages which intervention popup to show and tracks TikTok intent gate triggers.
final class InterventionManager: ObservableObject {

    // MARK: - Intervention Sheet State
    @Published var showTikTokGate: Bool = false
    @Published var showPuzzleBreak: Bool = false
    @Published var showBreathwork: Bool = false

    // MARK: - TikTok Intent Log
    @Published private(set) var intentLog: [IntentEntry] = []

    struct IntentEntry: Identifiable {
        let id = UUID()
        let reason: String
        let timestamp: Date
    }

    // MARK: - Triggers

    /// Call this when the user taps "Open TikTok" or when TikTok launch is detected.
    func triggerTikTokGate() {
        showTikTokGate = true
    }

    func triggerPuzzleBreak() {
        showPuzzleBreak = true
    }

    func triggerBreathwork() {
        showBreathwork = true
    }

    // MARK: - Logging

    func logTikTokIntent(reason: String) {
        let entry = IntentEntry(reason: reason, timestamp: .now)
        intentLog.insert(entry, at: 0)
    }
}
