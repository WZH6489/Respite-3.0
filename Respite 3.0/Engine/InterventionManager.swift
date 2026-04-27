import Foundation
import Combine

enum RegulationChallenge: String, Equatable, Identifiable {
    case puzzle
    case breathwork

    var id: String { rawValue }
}

enum PuzzleLaunchMode: String, Equatable {
    case tile
    case math
}

/// Manages which intervention popup to show and tracks TikTok intent gate triggers.
final class InterventionManager: ObservableObject {

    // MARK: - Intervention Sheet State
    @Published var showTikTokGate: Bool = false
    @Published var showPuzzleBreak: Bool = false
    @Published var showBreathwork: Bool = false
    @Published var preferredPuzzleLaunchMode: PuzzleLaunchMode = .tile

    /// Deep link from shield (`regulate://`) — full-screen regulation flow.
    @Published var regulationChallenge: RegulationChallenge? = nil
    @Published var regulationPuzzleLaunchMode: PuzzleLaunchMode = .tile

    /// Deep link from TikTok shield (`regulate://intent`) — full-screen intent gate.
    @Published var regulationIntentGate: Bool = false

    /// Legacy picker presentation flag. `regulate://tiktok/options` now opens the recommended intervention directly.
    @Published var showTikTokUnlockPicker: Bool = false

    /// When true, completing puzzle/breathwork unlocks intent-gate apps (`TikTokShieldManager`), not daily-limit shields.
    var regulationUnlocksTikTokOnly: Bool = false

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

    func triggerPuzzleBreak(mode: PuzzleLaunchMode = .tile) {
        preferredPuzzleLaunchMode = mode
        showPuzzleBreak = true
    }

    func triggerBreathwork() {
        showBreathwork = true
    }

    /// Opens the recommended intervention based on current behavior signals.
    func triggerAdaptiveIntervention() {
        let recommendation = RecoveryInsightsStore.currentSnapshot().recommendedIntervention
        switch recommendation {
        case .puzzle:
            triggerPuzzleBreak(mode: .math)
        case .breathwork:
            triggerBreathwork()
        }
    }

    func openRegulationChallenge(
        _ challenge: RegulationChallenge,
        unlocksTikTok: Bool = false,
        puzzleMode: PuzzleLaunchMode = .tile
    ) {
        regulationUnlocksTikTokOnly = unlocksTikTok
        if challenge == .puzzle {
            regulationPuzzleLaunchMode = puzzleMode
        }
        regulationChallenge = challenge
    }

    func clearRegulationChallenge() {
        regulationChallenge = nil
        regulationUnlocksTikTokOnly = false
        regulationPuzzleLaunchMode = .tile
    }

    func openRegulationIntentGate() {
        regulationIntentGate = true
    }

    func openRecommendedTikTokIntervention() {
        let recommendation = RecoveryInsightsStore.currentSnapshot().recommendedIntervention
        switch recommendation {
        case .puzzle:
            openRegulationChallenge(.puzzle, unlocksTikTok: true, puzzleMode: .math)
        case .breathwork:
            openRegulationChallenge(.breathwork, unlocksTikTok: true)
        }
    }

    func openTikTokUnlockPicker() {
        showTikTokUnlockPicker = false
        openRecommendedTikTokIntervention()
    }

    // MARK: - Logging

    func logTikTokIntent(reason: String) {
        let entry = IntentEntry(reason: reason, timestamp: .now)
        intentLog.insert(entry, at: 0)
    }
}
