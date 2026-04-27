@preconcurrency import ManagedSettings
import UIKit

@objc(RespiteShieldActionExtension)
class RespiteShieldActionExtension: ShieldActionDelegate {

    nonisolated override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let isIntentGateApp = ShieldActionIntentGateMatching.matchesApplicationToken(application)
        route(action: action, isIntentGateTarget: isIntentGateApp, completionHandler: completionHandler)
    }

    nonisolated override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let isIntentGateCategory = ShieldActionIntentGateMatching.matchesActivityCategory(category)
        route(action: action, isIntentGateTarget: isIntentGateCategory, completionHandler: completionHandler)
    }

    nonisolated override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let isIntentGateDomain = ShieldActionIntentGateMatching.matchesWebDomain(webDomain)
        route(action: action, isIntentGateTarget: isIntentGateDomain, completionHandler: completionHandler)
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

    nonisolated private func route(
        action: ShieldAction,
        isIntentGateTarget: Bool,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            let url = isIntentGateTarget
                ? URL(string: "regulate://tiktok/options")!
                : URL(string: "regulate://adaptive")!
            openURL(url) {
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            let url = isIntentGateTarget
                ? URL(string: "regulate://intent")!
                : URL(string: "regulate://breathwork")!
            openURL(url) {
                completionHandler(.close)
            }
        default:
            completionHandler(.close)
        }
    }
}
