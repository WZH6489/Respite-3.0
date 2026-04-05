import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// All app shields use **one** `ManagedSettingsStore`. Two stores shielding the same app caused iOS to show the generic “Restricted” UI instead of Respite’s shield.
@MainActor
final class ShieldManager: ObservableObject {
    static let shared = ShieldManager()

    private let store = ManagedSettingsStore()
    private let settings = RegulationSettingsStore()
    private var graceTimer: Timer?

    private init() {
        // Older builds used a second named store for intent-gate apps; clear it so nothing stays double-shielded.
        let legacyName = ManagedSettingsStore.Name(rawValue: "com.stormforge.tiktok")
        let legacy = ManagedSettingsStore(named: legacyName)
        legacy.shield.applications = nil
    }

    /// Clears all shields (categories, web, apps).
    func releaseShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// Applies shields: union of daily-limit + intent-gate apps in **one** store; respects grace windows.
    func reapplyAllShields() {
        // Regulation grace — full unlock first
        if settings.isUnlocked, let exp = settings.unlockExpiresAt, Date() < exp {
            releaseShield()
            return
        }

        _ = TikTokIdleLogic.clearTikTokUnlockIfNeeded(settings: settings)

        let monitored = settings.loadSelection()
        let tiktokSel = settings.loadTikTokSelection()

        let monitoredApps = monitored?.applicationTokens ?? []
        let tiktokApps = tiktokSel?.applicationTokens ?? []
        var apps = monitoredApps.union(tiktokApps)

        let hasCategories = !(monitored?.categoryTokens.isEmpty ?? true)
        let hasWeb = !(monitored?.webDomainTokens.isEmpty ?? true)
        if apps.isEmpty && !hasCategories && !hasWeb {
            releaseShield()
            return
        }

        // Intent gate: stay unshielded until idle (no usage for N minutes) — see `TikTokIdleLogic`.
        if TikTokIdleLogic.shouldTikTokStayUnshielded(settings: settings) {
            apps = apps.subtracting(tiktokApps)
        }

        store.shield.applications = apps.isEmpty ? nil : apps
        if let monitored, !monitored.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(monitored.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }
        if let monitored, !monitored.webDomainTokens.isEmpty {
            store.shield.webDomains = monitored.webDomainTokens
        } else {
            store.shield.webDomains = nil
        }
    }

    /// Backwards-compatible name used by grace expiry paths.
    func applyShield() {
        reapplyAllShields()
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
            reapplyAllShields()
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

// MARK: - TikTok / intent gate (UserDefaults + timers only; shields go through `ShieldManager`)

@MainActor
final class TikTokShieldManager: ObservableObject {
    static let shared = TikTokShieldManager()

    private let settings = RegulationSettingsStore()
    private var graceTimer: Timer?

    private init() {}

    func applyShield() {
        ShieldManager.shared.reapplyAllShields()
    }

    /// After completing check-in: unshield intent-gate apps until idle (no usage for `tiktokIdleMinutesAfterExit`).
    func grantUnlockAfterCheckIn() {
        settings.tiktokIsUnlocked = true
        settings.tiktokUnlockExpiresAt = nil
        settings.lastTikTokUnlockAt = Date()
        settings.lastTikTokUsageAt = nil
        ShieldManager.shared.reapplyAllShields()
        scheduleIdlePolling()
    }

    func checkGraceExpired() {
        ShieldManager.shared.reapplyAllShields()
        if !settings.tiktokIsUnlocked {
            graceTimer?.invalidate()
            graceTimer = nil
        }
    }

    /// Restarts the 1-minute idle poll after launch if the user was still in an unlocked session.
    func resumeIdlePollingIfNeeded() {
        guard settings.tiktokIsUnlocked else { return }
        guard graceTimer == nil else { return }
        scheduleIdlePolling()
    }

    func applyShieldIfNeeded() {
        ShieldManager.shared.reapplyAllShields()
    }

    private func scheduleIdlePolling() {
        graceTimer?.invalidate()
        graceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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

    /// Usage on intent-gate apps (fires when cumulative usage crosses threshold in the interval).
    static func restartTikTokUsageMonitoring(settings: RegulationSettingsStore = RegulationSettingsStore()) throws {
        center.stopMonitoring([TikTokUsageActivity.name])
        guard let tiktok = settings.loadTikTokSelection() else { return }
        let hasApps = !tiktok.applicationTokens.isEmpty
        guard hasApps else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let threshold = DateComponents(minute: 1)
        let event = DeviceActivityEvent(
            applications: tiktok.applicationTokens,
            categories: tiktok.categoryTokens,
            webDomains: tiktok.webDomainTokens,
            threshold: threshold
        )

        try center.startMonitoring(
            TikTokUsageActivity.name,
            during: schedule,
            events: [TikTokUsageActivity.usageThreshold: event]
        )
    }
}
