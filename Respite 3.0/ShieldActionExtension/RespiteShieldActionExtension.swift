import ManagedSettings
import UIKit

final class RespiteShieldActionExtension: ShieldActionDelegate {
    nonisolated override init() {
        super.init()
    }

    nonisolated override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let path: String
        switch action {
        case .primaryButtonPressed:
            path = "puzzle"
        case .secondaryButtonPressed:
            path = "breathwork"
        @unknown default:
            completionHandler(.close)
            return
        }

        guard let url = URL(string: "regulate://\(path)") else {
            completionHandler(.close)
            return
        }

        openURL(url) {
            completionHandler(.close)
        }
    }

    /// `UIApplication.shared` is unavailable to Shield Action extensions; use the shared application handle.
    nonisolated private func openURL(_ url: URL, completion: @escaping () -> Void) {
        guard
            let app = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication
        else {
            completion()
            return
        }
        app.open(url, options: [:], completionHandler: { _ in
            completion()
        })
    }
}
