@preconcurrency import ManagedSettings
import UIKit

@objc(RespiteShieldActionExtension)
class RespiteShieldActionExtension: ShieldActionDelegate {

    nonisolated override init() { super.init() }

    nonisolated override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            openURL(URL(string: "regulate://intent")!) {
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            openURL(URL(string: "regulate://tiktok/options")!) {
                completionHandler(.close)
            }
        @unknown default:
            completionHandler(.close)
        }
    }

    nonisolated private func openURL(_ url: URL, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard
                let obj = UIApplication.perform(NSSelectorFromString("sharedApplication"))?
                    .takeUnretainedValue() as? UIApplication
            else {
                completion()
                return
            }
            obj.open(url, options: [:]) { _ in
                completion()
            }
        }
    }
}
