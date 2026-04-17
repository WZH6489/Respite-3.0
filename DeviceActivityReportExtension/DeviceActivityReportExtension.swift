//
//  DeviceActivityReportExtension.swift
//  DeviceActivityReportExtension
//
//  Created by William Huang on 2026-04-01.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct DeviceActivityReportExtension: DeviceActivity.DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
