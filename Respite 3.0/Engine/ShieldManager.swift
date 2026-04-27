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

        // Daily-limit targets should only be shielded after threshold is reached.
        let monitoredApps = settings.dailyLimitTriggered ? (monitored?.applicationTokens ?? []) : []
        let intentApps = tiktokSel?.applicationTokens ?? []
        var apps = monitoredApps.union(intentApps)

        let monitoredCategories = settings.dailyLimitTriggered ? (monitored?.categoryTokens ?? []) : []
        let intentCategories = tiktokSel?.categoryTokens ?? []
        var categories = monitoredCategories.union(intentCategories)

        let monitoredWeb = settings.dailyLimitTriggered ? (monitored?.webDomainTokens ?? []) : []
        let intentWeb = tiktokSel?.webDomainTokens ?? []
        var webDomains = monitoredWeb.union(intentWeb)

        let hasCategories = !categories.isEmpty
        let hasWeb = !webDomains.isEmpty
        if apps.isEmpty && !hasCategories && !hasWeb {
            releaseShield()
            return
        }

        // Intent gate: stay unshielded until idle (no usage for N minutes) — applies to all intent-gate targets.
        if TikTokIdleLogic.shouldTikTokStayUnshielded(settings: settings) {
            apps = apps.subtracting(intentApps)
            categories = categories.subtracting(intentCategories)
            webDomains = webDomains.subtracting(intentWeb)
        }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }

    /// Backwards-compatible name used by grace expiry paths.
    func applyShield() {
        reapplyAllShields()
    }

    func grantTemporaryUnlock(graceMinutes: Int? = nil) {
        let minutes = graceMinutes ?? settings.gracePeriodMinutes
        settings.isUnlocked = true
        settings.unlockExpiresAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        settings.dailyLimitTriggered = true
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
            guard let self else { return }
            Task { @MainActor [self] in
                self.checkGraceExpired()
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

    /// After completing check-in: unshield intent-gate targets until idle (no usage for `tiktokIdleMinutesAfterExit`).
    /// Also sets a concrete active-session expiry so immediate re-open attempts do not get re-shielded.
    func grantUnlockAfterCheckIn() {
        let idleMinutes = max(1, settings.tiktokIdleMinutesAfterExit)
        let now = Date()

        settings.tiktokIsUnlocked = true
        settings.tiktokUnlockExpiresAt = now.addingTimeInterval(TimeInterval(idleMinutes * 60))
        settings.lastTikTokUnlockAt = now
        settings.lastTikTokUsageAt = nil

        ShieldManager.shared.releaseShield()
        ShieldManager.shared.reapplyAllShields()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            ShieldManager.shared.reapplyAllShields()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            ShieldManager.shared.reapplyAllShields()
        }

        do {
            try RegulationActivityScheduler.restartTikTokUsageMonitoring(settings: settings)
        } catch {
            // Keep unlock session active even if monitor restart fails.
        }
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
            guard let self else { return }
            Task { @MainActor [self] in
                self.checkGraceExpired()
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

    /// Usage on intent-gate targets (fires when cumulative usage crosses threshold in the interval).
    static func restartTikTokUsageMonitoring(settings: RegulationSettingsStore = RegulationSettingsStore()) throws {
        center.stopMonitoring([TikTokUsageActivity.name])
        guard let tiktok = settings.loadTikTokSelection() else { return }
        let hasTargets =
            !tiktok.applicationTokens.isEmpty
            || !tiktok.categoryTokens.isEmpty
            || !tiktok.webDomainTokens.isEmpty
        guard hasTargets else { return }

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
