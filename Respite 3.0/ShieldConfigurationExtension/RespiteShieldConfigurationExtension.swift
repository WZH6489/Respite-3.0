@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import UIKit

@objc(RespiteShieldConfigurationExtension)
class RespiteShieldConfigurationExtension: ShieldConfigurationDataSource {

    nonisolated override init() { super.init() }

    /// Always return a custom shield configuration quickly.
    ///
    /// If this extension does extra work (for example decoding selections) and takes too long,
    /// iOS falls back to the default Apple restriction UI.
    nonisolated override func configuration(shielding application: Application) -> ShieldConfiguration {
        unifiedConfiguration()
    }

    nonisolated override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        unifiedConfiguration()
    }

    nonisolated override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        unifiedConfiguration()
    }

    nonisolated override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        unifiedConfiguration()
    }

    nonisolated private func unifiedConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "Respite", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Take a short reset before continuing.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Respite - intelligently shuffled", color: .white),
            primaryButtonBackgroundColor: .systemOrange,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Quick check-in", color: .white)
        )
    }
}
