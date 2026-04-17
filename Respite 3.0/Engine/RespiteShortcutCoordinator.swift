import Foundation

/// Bridges `RunTikTokBreathingGateIntent` (`perform` awaits until the user finishes the breathing gate).
@MainActor
final class RespiteShortcutCoordinator {
    static let shared = RespiteShortcutCoordinator()

    private weak var interventionsRef: InterventionManager?
    private var breathingContinuation: CheckedContinuation<Void, Never>?
    private(set) var pendingOpenTikTokWhenDone: Bool = false

    /// True while `RunTikTokBreathingGateIntent.perform()` is awaiting Continue (Shortcuts still shows “Opening…”).
    var hasPendingShortcutIntent: Bool { breathingContinuation != nil }

    private init() {}

    func attach(_ interventions: InterventionManager) {
        interventionsRef = interventions
    }

    func runBreathingGateForShortcut(openTikTokWhenDone: Bool) async {
        await withCheckedContinuation { cont in
            guard let iv = interventionsRef else {
                cont.resume()
                return
            }
            pendingOpenTikTokWhenDone = openTikTokWhenDone
            breathingContinuation = cont
            iv.presentBreathingGate(.shortcutAutomation)
        }
    }

    func completeBreathingGate() {
        breathingContinuation?.resume()
        breathingContinuation = nil
        pendingOpenTikTokWhenDone = false
    }
}
