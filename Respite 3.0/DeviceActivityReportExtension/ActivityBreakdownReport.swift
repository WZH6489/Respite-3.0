import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

struct ActivityBreakdownConfiguration {
    var totalDuration: TimeInterval
    var categories: [ActivityCategoryBreakdown]
}

struct ActivityCategoryBreakdown: Identifiable {
    let id: String
    let name: String
    let duration: TimeInterval
    let apps: [ActivityAppBreakdown]
}

struct ActivityAppBreakdown: Identifiable {
    let id: String
    let name: String
    let duration: TimeInterval
}

private func computeActivityBreakdown(
    from data: DeviceActivityResults<DeviceActivityData>
) async -> ActivityBreakdownConfiguration {
    var totalDuration: TimeInterval = 0

    struct CategoryAccumulator {
        var duration: TimeInterval = 0
        var apps: [String: TimeInterval] = [:]
    }

    var categories: [String: CategoryAccumulator] = [:]

    for await activity in data {
        for await segment in activity.activitySegments {
            totalDuration += segment.totalActivityDuration

            for await categoryActivity in segment.categories {
                    let categoryName = categoryActivity.category.localizedDisplayName ?? "Unknown Category"

                var acc = categories[categoryName] ?? CategoryAccumulator()
                acc.duration += categoryActivity.totalActivityDuration

                for await appActivity in categoryActivity.applications {
                    let app = appActivity.application
                    let appName = app.localizedDisplayName ?? app.bundleIdentifier ?? "Unknown App"
                    acc.apps[appName, default: 0] += appActivity.totalActivityDuration
                }

                categories[categoryName] = acc
            }
        }
    }

    let categoryRows = categories
        .map { (categoryName, acc) -> ActivityCategoryBreakdown in
            let appRows = acc.apps
                .map { (appName, duration) in ActivityAppBreakdown(id: appName, name: appName, duration: duration) }
                .sorted { $0.duration > $1.duration }
                .prefix(10)
                .map { $0 }

            return ActivityCategoryBreakdown(
                id: categoryName,
                name: categoryName,
                duration: acc.duration,
                apps: appRows
            )
        }
        .sorted { $0.duration > $1.duration }

    return ActivityBreakdownConfiguration(totalDuration: totalDuration, categories: categoryRows)
}

struct BarGraphActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .respiteBarGraph
    let content: (ActivityBreakdownConfiguration) -> ActivityBreakdownView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityBreakdownConfiguration {
        await computeActivityBreakdown(from: data)
    }
}

struct PieChartActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .respitePieChart
    let content: (ActivityBreakdownConfiguration) -> ActivityBreakdownView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityBreakdownConfiguration {
        // Reuse the same breakdown configuration for both chart contexts.
        await computeActivityBreakdown(from: data)
    }
}

private extension DeviceActivityReport.Context {
    static let respiteBarGraph = Self("Respite Bar Graph")
    static let respitePieChart = Self("Respite Pie Chart")
}

