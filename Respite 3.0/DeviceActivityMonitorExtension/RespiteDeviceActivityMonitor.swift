import DeviceActivity
import Foundation

private let tiktokUsageActivityId = "com.stormforge.Respite.tiktokUsage"
private let tiktokUsageThresholdId = "tiktokUsageThreshold"

@objc(RespiteDeviceActivityMonitor)
final class RespiteDeviceActivityMonitor: DeviceActivityMonitor {
    nonisolated override init() {
        super.init()
    }

    nonisolated override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        RegulationMonitorShield.applyShieldIfLocked()
    }

    nonisolated override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    nonisolated override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if activity.rawValue == tiktokUsageActivityId, event.rawValue == tiktokUsageThresholdId {
            RegulationMonitorShield.recordTikTokUsageNow()
            RegulationMonitorShield.restartTikTokUsageMonitoring()
        }
        RegulationMonitorShield.applyShieldAfterThreshold()
    }
}
