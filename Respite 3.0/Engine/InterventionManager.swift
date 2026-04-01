import Foundation
import Combine

enum RegulationChallenge: String, Equatable, Identifiable {
    case puzzle
    case breathwork

    var id: String { rawValue }
}

/// Manages which intervention popup to show and tracks TikTok intent gate triggers.
final class InterventionManager: ObservableObject {

    // MARK: - Intervention Sheet State
    @Published var showTikTokGate: Bool = false
    @Published var showPuzzleBreak: Bool = false
    @Published var showBreathwork: Bool = false

    /// Deep link from shield (`regulate://`) — full-screen regulation flow.
    @Published var regulationChallenge: RegulationChallenge? = nil

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

    func openRegulationChallenge(_ challenge: RegulationChallenge) {
        regulationChallenge = challenge
    }

    func clearRegulationChallenge() {
        regulationChallenge = nil
    }

    // MARK: - Logging

    func logTikTokIntent(reason: String) {
        let entry = IntentEntry(reason: reason, timestamp: .now)
        intentLog.insert(entry, at: 0)
    }
}
