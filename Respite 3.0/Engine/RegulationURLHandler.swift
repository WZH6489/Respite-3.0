import Foundation

enum RegulationURLHandler {
    /// Handles `regulate://` URLs from the Screen Time shield, Shortcuts, and other automations.
    static func handle(_ url: URL, interventions: InterventionManager) {
        guard url.scheme?.lowercased() == "regulate" else { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

        if host == "tiktok-breath" || path == "tiktok-breath" {
            guard interventions.shouldAcceptPreTikTokBreathAutomationDeepLink() else { return }
            if interventions.presentedBreathingGate == .shortcutAutomation { return }
            interventions.triggerTikTokBreathGate()
            return
        }
        if host == "puzzle" || path == "puzzle" {
            guard interventions.shouldAcceptRegulationPuzzleDeepLink() else { return }
            if interventions.regulationChallenge == .puzzle { return }
            if interventions.presentedBreathingGate == .shortcutAutomation { return }
            interventions.openRegulationChallenge(.puzzle)
            return
        }
        if host == "breathwork" || path == "breathwork" {
            guard interventions.shouldAcceptRegulationBreathworkDeepLink() else { return }
            if interventions.regulationChallenge == .breathwork { return }
            if interventions.presentedBreathingGate == .shortcutAutomation { return }
            interventions.openRegulationChallenge(.breathwork)
            return
        }
    }
}
