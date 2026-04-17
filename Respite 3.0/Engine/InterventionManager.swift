import Foundation
import Combine

enum RegulationChallenge: String, Equatable, Identifiable {
    case puzzle
    case breathwork

    var id: String { rawValue }
}

/// Why the unified breathing gate (5 slow breaths) is on screen.
enum BreathingGateReason: String, Identifiable, Equatable, Hashable {
    /// Shortcuts, dashboard, or `regulate://tiktok-breath`.
    case externalLaunch
    /// Screen Time shield chose breathwork — grants grace when breaths finish.
    case regulationShield
    /// Returned after being away longer than the idle threshold.
    case idleReturn
    /// Random pick after grace expired while you stayed in the app.
    case postGraceRandom
    /// Shortcuts `RunTikTokBreathingGateIntent` — blocks until user completes; may chain Open TikTok.
    case shortcutAutomation

    var id: String { rawValue }
}

/// Manages interventions and the single unified breathing gate.
final class InterventionManager: ObservableObject {

    private static var deepLinkDefaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    // MARK: - Intervention Sheet State

    /// Unified breathing gate (full-screen). Nil when not shown.
    @Published var presentedBreathingGate: BreathingGateReason?
    @Published var showPuzzleBreak: Bool = false

    /// Deep link from shield (`regulate://`) — full-screen regulation flow.
    @Published var regulationChallenge: RegulationChallenge? = nil

    // MARK: - Gate log
    @Published private(set) var intentLog: [IntentEntry] = []

    /// Ignores `regulate://tiktok-breath` until this date (after user completes the gate) so Shortcuts/banner replays don’t reopen the gate.
    private var preTikTokBreathAutomationDeepLinkQuietUntil: Date?

    /// Ignores `regulate://breathwork` briefly after leaving the regulation breathwork flow (Shortcuts replay).
    private var regulationBreathworkDeepLinkQuietUntil: Date?

    /// Ignores `regulate://puzzle` briefly after leaving the regulation puzzle flow after a successful solve.
    private var regulationPuzzleDeepLinkQuietUntil: Date?

    struct IntentEntry: Identifiable {
        let id = UUID()
        let reason: String
        let timestamp: Date
    }

    // MARK: - Breathing gate

    func presentBreathingGate(_ reason: BreathingGateReason) {
        presentedBreathingGate = reason
    }

    func dismissBreathingGate() {
        presentedBreathingGate = nil
    }

    /// Dashboard / legacy name.
    func triggerTikTokBreathGate() {
        if presentedBreathingGate == .shortcutAutomation { return }
        presentBreathingGate(.externalLaunch)
    }

    // MARK: - Deep link quiet periods

    func armPreTikTokBreathAutomationDeepLinkQuietPeriod(duration: TimeInterval = 45) {
        let until = Date().addingTimeInterval(duration)
        preTikTokBreathAutomationDeepLinkQuietUntil = until
        Self.deepLinkDefaults.set(until, forKey: RegulationUserDefaultsKey.deepLinkTikTokBreathQuietUntil)
    }

    func shouldAcceptPreTikTokBreathAutomationDeepLink() -> Bool {
        if RegulationSettingsStore().isGraceUnlockActive { return false }
        if RegulationSettingsStore().isTikTokHandoffSuppressActive { return false }
        let mem = preTikTokBreathAutomationDeepLinkQuietUntil
        let disk = Self.deepLinkDefaults.object(forKey: RegulationUserDefaultsKey.deepLinkTikTokBreathQuietUntil) as? Date
        let until = max(mem ?? .distantPast, disk ?? .distantPast)
        return Date() >= until
    }

    func armRegulationBreathworkDeepLinkQuietPeriod() {
        let settings = RegulationSettingsStore()
        var until = Date().addingTimeInterval(90)
        if let exp = settings.unlockExpiresAt, exp > until {
            until = exp
        }
        regulationBreathworkDeepLinkQuietUntil = until
        Self.deepLinkDefaults.set(until, forKey: RegulationUserDefaultsKey.deepLinkBreathworkQuietUntil)
    }

    func shouldAcceptRegulationBreathworkDeepLink() -> Bool {
        if RegulationSettingsStore().isGraceUnlockActive { return false }
        if RegulationSettingsStore().isTikTokHandoffSuppressActive { return false }
        let mem = regulationBreathworkDeepLinkQuietUntil
        let disk = Self.deepLinkDefaults.object(forKey: RegulationUserDefaultsKey.deepLinkBreathworkQuietUntil) as? Date
        let until = max(mem ?? .distantPast, disk ?? .distantPast)
        return Date() >= until
    }

    func armRegulationPuzzleDeepLinkQuietPeriod() {
        let settings = RegulationSettingsStore()
        var until = Date().addingTimeInterval(90)
        if let exp = settings.unlockExpiresAt, exp > until {
            until = exp
        }
        regulationPuzzleDeepLinkQuietUntil = until
        Self.deepLinkDefaults.set(until, forKey: RegulationUserDefaultsKey.deepLinkPuzzleQuietUntil)
    }

    func shouldAcceptRegulationPuzzleDeepLink() -> Bool {
        if RegulationSettingsStore().isGraceUnlockActive { return false }
        let mem = regulationPuzzleDeepLinkQuietUntil
        let disk = Self.deepLinkDefaults.object(forKey: RegulationUserDefaultsKey.deepLinkPuzzleQuietUntil) as? Date
        let until = max(mem ?? .distantPast, disk ?? .distantPast)
        return Date() >= until
    }

    func triggerPuzzleBreak() {
        showPuzzleBreak = true
    }

    func openRegulationChallenge(_ challenge: RegulationChallenge) {
        regulationChallenge = challenge
    }

    func clearRegulationChallenge() {
        regulationChallenge = nil
    }

    /// After grace expires in the foreground, present one random gate from user settings.
    func tryPresentPostGraceRandomGate() {
        guard presentedBreathingGate == nil else { return }
        guard regulationChallenge == nil else { return }
        guard !showPuzzleBreak else { return }

        let store = RegulationSettingsStore()
        var options: [PostGraceOption] = []
        if store.postGraceRandomIncludeBreathing { options.append(.breathing) }
        if store.postGraceRandomIncludePuzzle { options.append(.puzzle) }
        guard let pick = options.randomElement() else { return }

        switch pick {
        case .breathing:
            presentBreathingGate(.postGraceRandom)
        case .puzzle:
            showPuzzleBreak = true
        }
    }

    private enum PostGraceOption {
        case breathing
        case puzzle
    }

    // MARK: - Logging

    func logBreathingGateCompletion(context: String) {
        let entry = IntentEntry(reason: context, timestamp: .now)
        intentLog.insert(entry, at: 0)
    }

    func logPreTikTokBreathGateCompletion() {
        logBreathingGateCompletion(context: "Calm breathing gate (5 breaths, 2s in / 3s out)")
    }
}
