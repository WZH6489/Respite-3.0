import ManagedSettings
import ManagedSettingsUI
import UIKit

final class RespiteShieldConfigurationExtension: ShieldConfigurationDataSource {
    nonisolated override init() {
        super.init()
    }

    nonisolated override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    nonisolated override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    nonisolated override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    nonisolated override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    nonisolated private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            icon: UIImage(systemName: "pause.circle.fill"),
            title: ShieldConfiguration.Label(text: "Pause", color: UIColor.label),
            subtitle: ShieldConfiguration.Label(
                text: "You've been here a while. Choose how you'd like to continue.",
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "I need to use this", color: UIColor.white),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Breathe instead", color: UIColor.white)
        )
    }
}
