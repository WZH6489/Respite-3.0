@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import UIKit

@objc(RespiteShieldConfigurationExtension)
class RespiteShieldConfigurationExtension: ShieldConfigurationDataSource {

    nonisolated override init() { super.init() }

    nonisolated override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(text: "Respite", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Take a moment before continuing.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Check in", color: .white),
            primaryButtonBackgroundColor: .systemOrange,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "More options", color: .white)
        )
    }

    nonisolated override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    nonisolated override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            title: ShieldConfiguration.Label(text: "Respite", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Take a moment before continuing.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Check in", color: .white),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "More options", color: .white)
        )
    }

    nonisolated override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }
}
