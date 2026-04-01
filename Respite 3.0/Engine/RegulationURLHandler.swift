import Foundation

enum RegulationURLHandler {
    static func handle(_ url: URL, interventions: InterventionManager) {
        guard url.scheme?.lowercased() == "regulate" else { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

        let challenge: RegulationChallenge?
        if host == "puzzle" || path == "puzzle" {
            challenge = .puzzle
        } else if host == "breathwork" || path == "breathwork" {
            challenge = .breathwork
        } else {
            challenge = nil
        }

        guard let challenge else { return }
        interventions.openRegulationChallenge(challenge)
    }
}
