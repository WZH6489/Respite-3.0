import Foundation
import os.log

private let log = Logger(subsystem: "com.stormforge.Respite-3-0", category: "URLHandler")

enum RegulationURLHandler {
    static func handle(_ url: URL, interventions: InterventionManager) {
        guard url.scheme?.lowercased() == "regulate" else { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

        // regulate://intent — intent-gate check-in (from Shortcuts automation or shield)
        if host == "intent" || path == "intent" {
            interventions.openRegulationIntentGate()
            return
        }

        // regulate://adaptive — choose intervention automatically from insights.
        if host == "adaptive" || path == "adaptive" {
            interventions.triggerAdaptiveIntervention()
            return
        }

        // regulate://tiktok/... — intent-gate unlock paths
        if host == "tiktok" {
            switch path {
            case "options":
                interventions.openRecommendedTikTokIntervention()
                return
            case "intent":
                interventions.openRegulationIntentGate()
                return
            case "puzzle":
                interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true)
                return
            case "breathwork":
                interventions.openRegulationChallenge(.breathwork, unlocksTikTok: true)
                return
            default:
                return
            }
        }

        // regulate://puzzle — daily-limit regulation (ShieldManager)
        let challenge: RegulationChallenge?
        if host == "puzzle" || path == "puzzle" {
            challenge = .puzzle
        } else if host == "breathwork" || path == "breathwork" {
            challenge = .breathwork
        } else {
            challenge = nil
        }

        guard let challenge else { return }
        interventions.openRegulationChallenge(challenge, unlocksTikTok: false)
    }
}
