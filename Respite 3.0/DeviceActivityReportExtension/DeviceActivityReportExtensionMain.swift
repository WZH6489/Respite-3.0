import DeviceActivity
import ExtensionKit
import SwiftUI

struct DeviceActivityReportExtensionMain: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        BarGraphActivityReport { configuration in
            ActivityBreakdownView(configuration: configuration)
        }
        PieChartActivityReport { configuration in
            ActivityBreakdownView(configuration: configuration)
        }
    }
}

