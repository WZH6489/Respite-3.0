import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ShieldManager: ObservableObject {
    static let shared = ShieldManager()

    private let store = ManagedSettingsStore()
    private let settings = RegulationSettingsStore()
    private var graceTimer: Timer?

    private init() {}

    /// Clears shields for monitored apps (tokens from saved selection).
    func releaseShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// Applies shields for all tokens in the saved `FamilyActivitySelection`.
    func applyShield() {
        guard let selection = settings.loadSelection() else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func grantTemporaryUnlock(graceMinutes: Int? = nil) {
        let minutes = graceMinutes ?? settings.gracePeriodMinutes
        settings.isUnlocked = true
        settings.unlockExpiresAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        releaseShield()
        scheduleGraceRelock()
    }

    func checkGraceExpired() {
        guard settings.isUnlocked, let expires = settings.unlockExpiresAt else { return }
        if Date() >= expires {
            settings.isUnlocked = false
            settings.unlockExpiresAt = nil
            applyShield()
            graceTimer?.invalidate()
            graceTimer = nil
        }
    }

    private func scheduleGraceRelock() {
        graceTimer?.invalidate()
        guard let expires = settings.unlockExpiresAt else { return }
        let interval = expires.timeIntervalSinceNow
        guard interval > 0 else {
            checkGraceExpired()
            return
        }
        graceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkGraceExpired()
            }
        }
        RunLoop.main.add(graceTimer!, forMode: .common)
    }
}

enum RegulationActivityScheduler {
    private static let center = DeviceActivityCenter()

    static func restartMonitoring(settings: RegulationSettingsStore = RegulationSettingsStore()) throws {
        center.stopMonitoring([RegulationActivity.name])
        guard let selection = settings.loadSelection() else { return }
        let hasTokens =
            !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
        guard hasTokens else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let threshold = DateComponents(minute: settings.pauseThresholdMinutes)
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )

        try center.startMonitoring(
            RegulationActivity.name,
            during: schedule,
            events: [RegulationActivity.usageThreshold: event]
        )
    }
}
