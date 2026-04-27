import DeviceActivity
import FamilyControls
import SwiftUI
import UserNotifications
import CoreLocation
import AppIntents
import UIKit

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection = FamilyActivitySelection()
    @State private var tiktokSelection = FamilyActivitySelection()
    @State private var profileName = UserProfileStore.displayName()
    @State private var profileBirthday = UserProfileStore.birthday() ?? Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var pauseMinutes = 15
    @State private var graceMinutes = 5
    @State private var streakGoalMinutes = 30
    @State private var tiktokIdleMinutes = 30
    @State private var selectedFocusPlan = RecoveryInsightsStore.selectedPlan()
    @State private var antiRelapseEnabled = RecoveryInsightsStore.antiRelapseEnabled()
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @State private var locationAuthorization: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
    @State private var scheduleErrorMessage: String?
    @State private var modeNoteMessage: String?
    @State private var reminderStatusMessage: String?
    @State private var healthKitWriteAuthorized = HealthKitMindfulnessStore.isWriteAuthorized
    @State private var healthKitConfirmationMessage: String?
    @State private var expandedModeTile: String?
    @State private var showResetConfirmation = false

    @State private var showMonitoredPicker = false
    @State private var showIntentGatePicker = false
    @AppStorage("dev.ui.interfaceMode") private var interfaceMode = "auto"
    @AppStorage("dev.ui.useTimePreview") private var useTimePreview = false
    @AppStorage("dev.ui.previewAuto") private var previewAuto = false
    @AppStorage("dev.ui.timePreviewHour") private var timePreviewHour = 12.0
    @AppStorage("dev.ui.colorIntensity") private var colorIntensity = 0.85
    @AppStorage("dev.ui.cardStyle") private var cardStyleRaw = RespiteCardStyle.liquid.rawValue
    @AppStorage("dev.ui.cardPalette") private var cardPaletteRaw = RespiteCardPalette.dayflow.rawValue
    @AppStorage("dev.ui.cardCustomRed") private var cardCustomRed = 0.30
    @AppStorage("dev.ui.cardCustomGreen") private var cardCustomGreen = 0.62
    @AppStorage("dev.ui.cardCustomBlue") private var cardCustomBlue = 0.84
    @AppStorage("dev.ui.weatherThemeMode") private var weatherThemeModeRaw = RespiteWeatherThemeMode.auto.rawValue
    @AppStorage("dev.ui.weatherThemeManualCondition") private var weatherThemeManualConditionRaw = DailyWeatherCondition.partlyCloudy.rawValue
    @AppStorage("notifications.reflection.hour") private var reflectionReminderHour = 21
    @AppStorage("notifications.reflection.minute") private var reflectionReminderMinute = 0
    @AppStorage("notifications.reflection.mode") private var reflectionReminderMode = 1
    @AppStorage("notifications.reflection.morning.hour") private var reflectionMorningHour = 8
    @AppStorage("notifications.reflection.morning.minute") private var reflectionMorningMinute = 0
    @AppStorage("notifications.reflection.evening.hour") private var reflectionEveningHour = 21
    @AppStorage("notifications.reflection.evening.minute") private var reflectionEveningMinute = 0
    @AppStorage("shortcuts.didOpenShortcutsPage") private var openedShortcutsPage = false
    @AppStorage("setup.checklist.completed") private var setupChecklistCompleted = false

    private let settings = RegulationSettingsStore()
    private var textPrimary: Color { .primary }
    private var textSecondary: Color { .secondary }
    private var textMuted: Color { .secondary.opacity(0.9) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    profileCard
                    accessCard
                    if !setupChecklistCompleted {
                        setupChecklistCard
                    }
                    if let healthKitConfirmationMessage {
                        infoCard(healthKitConfirmationMessage)
                    }
                    notificationsCard
                    visualControlsCard
                    modeComparisonCard

                    if authorizationStatus == .approved {
                        monitoredAppsCard
                        intentGateCard
                    }

                    focusPlanCard
                    streakGoalCard
                    shortcutsCard

                    if let scheduleErrorMessage {
                        errorCard(scheduleErrorMessage)
                    }
                    if let modeNoteMessage {
                        infoCard(modeNoteMessage)
                    }


                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .respiteTrackBottomBarScroll()
            .background(RespiteDynamicBackground())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                loadFromStore()
                await refreshPermissionStatuses()
            }
            .onReceive(AuthorizationCenter.shared.$authorizationStatus) { authorizationStatus = $0 }
            .sheet(isPresented: $showMonitoredPicker) {
                monitoredPickerSheet
            }
            .sheet(isPresented: $showIntentGatePicker) {
                intentGatePickerSheet
            }

        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adjust your boundaries")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
            Text("Simple controls for a calmer daily flow.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            TextField("Name", text: $profileName)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )

            DatePicker("Birthday", selection: $profileBirthday, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(RespiteTheme.pine)

            Text("Birthday is only used for a small in-app birthday surprise.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)

            Button("Save profile") {
                InteractionFeedback.tap()
                UserProfileStore.setDisplayName(profileName)
                UserProfileStore.setBirthday(profileBirthday)
                modeNoteMessage = "Profile updated."
            }
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.pine)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Access")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            accessRow(title: "Screen Time", status: screenTimeAccessLabel, isEnabled: authorizationStatus == .approved)
            accessRow(title: "Location", status: locationAccessLabel, isEnabled: locationAuthorization == .authorizedAlways || locationAuthorization == .authorizedWhenInUse)
            accessRow(title: "Notifications", status: notificationAccessLabel, isEnabled: notificationAuthorization == .authorized || notificationAuthorization == .provisional)
            accessRow(title: "HealthKit", status: healthKitAccessLabel, isEnabled: healthKitWriteAuthorized || HealthKitMindfulnessStore.isAvailable)

            if authorizationStatus != .approved {
                actionButton(title: authorizationStatus == .notDetermined ? "Request Screen Time access" : "Try Screen Time again") {
                    Task { await requestAuthorization() }
                }
            }

            if notificationAuthorization == .notDetermined {
                actionButton(title: "Enable notifications") {
                    Task { await requestNotificationAuthorization() }
                }
            }

            if HealthKitMindfulnessStore.isAvailable && !healthKitWriteAuthorized {
                actionButton(title: "Enable HealthKit mindfulness write") {
                    Task { await requestHealthKitAuthorization() }
                }
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Text("Daily reflection reminder")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Picker("Reminder frequency", selection: $reflectionReminderMode) {
                Text("One").tag(1)
                Text("Morning + night").tag(2)
            }
            .pickerStyle(.segmented)

            if reflectionReminderMode == 2 {
                VStack(spacing: 8) {
                    DatePicker(
                        "Morning reminder",
                        selection: reflectionMorningDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Night reminder",
                        selection: reflectionEveningDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
                .datePickerStyle(.compact)
                .tint(RespiteTheme.pine)
            } else {
                DatePicker(
                    "Reminder time",
                    selection: reflectionReminderDateBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .tint(RespiteTheme.pine)
            }

            Button("Save reminder") {
                InteractionFeedback.tap()
                Task { await scheduleReflectionReminder() }
            }
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.pine)

            if let reminderStatusMessage {
                Text(reminderStatusMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var visualControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual controls")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance mode")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Picker("Appearance mode", selection: $interfaceMode) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Auto").tag("auto")
                }
                .pickerStyle(.segmented)
            }

            Divider().overlay(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.16))

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview background time")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Picker("Preview background time", selection: previewModeBinding) {
                    Text("Off").tag(VisualPreviewMode.off)
                    Text("Manual").tag(VisualPreviewMode.manual)
                    Text("Auto").tag(VisualPreviewMode.auto)
                }
                .pickerStyle(.segmented)

                if previewMode == .manual {
                    Text("Time: \(formattedPreviewTime)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textMuted)
                    Slider(value: $timePreviewHour, in: 0...23.99, step: 0.25, onEditingChanged: { editing in
                        if !editing { InteractionFeedback.tap() }
                    })
                        .tint(RespiteTheme.pine)
                } else if previewMode == .auto {
                    Text("Auto uses local sunrise/sunset when location is available.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textMuted)
                }
            }

            Divider().overlay(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.16))

            VStack(alignment: .leading, spacing: 8) {
                Text("Weather-based background")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Picker("Weather-based background", selection: weatherThemeModeBinding) {
                    Text("Off").tag(RespiteWeatherThemeMode.off)
                    Text("Manual").tag(RespiteWeatherThemeMode.manual)
                    Text("Auto").tag(RespiteWeatherThemeMode.auto)
                }
                .pickerStyle(.segmented)

                if selectedWeatherThemeMode == .manual {
                    Picker("Weather condition", selection: manualWeatherConditionBinding) {
                        ForEach(DailyWeatherCondition.allCases.filter { $0 != .unknown }) { condition in
                            Text(condition.title).tag(condition)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text(selectedWeatherThemeMode == .off
                     ? "Uses normal time-based background only."
                     : selectedWeatherThemeMode == .auto
                        ? "Adjusts the background using your live local weather."
                        : "Forces the background to a specific weather mood.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }

            Divider().overlay(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.16))

            VStack(alignment: .leading, spacing: 8) {
                Text("Card style")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Picker("Card style", selection: cardStyleBinding) {
                    ForEach(RespiteCardStyle.allCases, id: \.rawValue) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(cardStyleDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RespiteCardPalette.allCases, id: \.rawValue) { palette in
                            let chipTint = palette == .custom ? customCardTint : palette.tint
                            Button {
                                InteractionFeedback.tap()
                                cardPaletteRaw = palette.rawValue
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(chipTint)
                                        .frame(width: 9, height: 9)
                                    Text(palette.title)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedCardPalette == palette ? Color.white : textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(minWidth: 72)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selectedCardPalette == palette ? chipTint : Color.white.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }

                if selectedCardPalette == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom accent color")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary)

                        ColorPicker("Pick color", selection: customCardColorBinding, supportsOpacity: false)
                            .font(.system(size: 12, weight: .medium, design: .rounded))

                        Text("Used across Opaque, Frosted, and Liquid card styles.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(textMuted)
                    }
                    .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Color intensity: \(Int(clampedColorIntensity * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
                Slider(value: $colorIntensity, in: 0.35...1.40, step: 0.05, onEditingChanged: { editing in
                    if !editing { InteractionFeedback.tap() }
                })
                    .tint(RespiteTheme.pine)
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var modeComparisonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How these two modes differ")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Group {
                if horizontalSizeClass == .compact {
                    VStack(spacing: 10) {
                        modeTile(
                            id: "intentGate",
                            title: "Intent gate",
                            subtitle: "Runs at app open",
                            detail: "You do a quick check-in before opening selected apps.",
                            tint: RespiteTheme.berryAccent
                        )
                        modeTile(
                            id: "dailyLimit",
                            title: "Daily limit",
                            subtitle: "Apple standard App Limit",
                            detail: "Uses Apple’s standard Screen Time limit behavior after your time is used.",
                            tint: RespiteTheme.duskBlue
                        )
                    }
                } else {
                    HStack(spacing: 10) {
                        modeTile(
                            id: "intentGate",
                            title: "Intent gate",
                            subtitle: "Runs at app open",
                            detail: "You do a quick check-in before opening selected apps.",
                            tint: RespiteTheme.berryAccent
                        )
                        modeTile(
                            id: "dailyLimit",
                            title: "Daily limit",
                            subtitle: "Apple standard App Limit",
                            detail: "Uses Apple’s standard Screen Time limit behavior after your time is used.",
                            tint: RespiteTheme.duskBlue
                        )
                    }
                }
            }

            Text("Apps can only belong to one mode at a time.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func modeTile(id: String, title: String, subtitle: String, detail: String, tint: Color) -> some View {
        let expanded = expandedModeTile == id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Spacer(minLength: 0)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(textMuted)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: expanded)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            InteractionFeedback.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedModeTile = expanded ? nil : id
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.22).opacity(0.8), lineWidth: 1)
                )
        )
    }

    private var monitoredAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily limit")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Text("Apple standard Screen Time limit for selected apps, categories, or sites.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)

            pickerTriggerRow(
                title: "Apps, categories, or sites to monitor",
                subtitle: selectionSummary(selection),
                icon: "chart.bar.doc.horizontal",
                tint: RespiteTheme.duskBlue
            ) {
                showMonitoredPicker = true
            }

            stepperRow(
                title: "Pause after",
                valueText: "\(pauseMinutes) min",
                canDecrease: pauseMinutes > 5 && authorizationStatus == .approved,
                canIncrease: pauseMinutes < 120 && authorizationStatus == .approved,
                decrease: {
                    guard authorizationStatus == .approved, pauseMinutes > 5 else { return }
                    pauseMinutes -= 5
                    settings.pauseThresholdMinutes = pauseMinutes
                    restartMonitoring()
                },
                increase: {
                    guard authorizationStatus == .approved, pauseMinutes < 120 else { return }
                    pauseMinutes += 5
                    settings.pauseThresholdMinutes = pauseMinutes
                    restartMonitoring()
                }
            )

            stepperRow(
                title: "Extra Time",
                valueText: "\(graceMinutes) min",
                canDecrease: graceMinutes > 1,
                canIncrease: graceMinutes < 60,
                decrease: {
                    guard graceMinutes > 1 else { return }
                    graceMinutes -= 1
                    settings.gracePeriodMinutes = graceMinutes
                },
                increase: {
                    guard graceMinutes < 60 else { return }
                    graceMinutes += 1
                    settings.gracePeriodMinutes = graceMinutes
                }
            )

        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var intentGateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intent gate")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Text("Quick check-in before opening selected apps.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)

            pickerTriggerRow(
                title: "Apps, categories, or sites that need a check-in",
                subtitle: selectionSummary(tiktokSelection),
                icon: "hand.raised.fill",
                tint: RespiteTheme.berryAccent
            ) {
                showIntentGatePicker = true
            }

            stepperRow(
                title: "Check-in again after",
                valueText: "\(tiktokIdleMinutes) min",
                canDecrease: tiktokIdleMinutes > 5,
                canIncrease: tiktokIdleMinutes < 180,
                decrease: {
                    guard tiktokIdleMinutes > 5 else { return }
                    tiktokIdleMinutes -= 5
                    settings.tiktokIdleMinutesAfterExit = tiktokIdleMinutes
                    Task { @MainActor in ShieldManager.shared.reapplyAllShields() }
                },
                increase: {
                    guard tiktokIdleMinutes < 180 else { return }
                    tiktokIdleMinutes += 5
                    settings.tiktokIdleMinutesAfterExit = tiktokIdleMinutes
                    Task { @MainActor in ShieldManager.shared.reapplyAllShields() }
                }
            )

        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var streakGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Momentum streak goal")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Text("Target: \(streakGoalMinutes) min saved/day")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Slider(
                value: Binding(
                    get: { Double(streakGoalMinutes) },
                    set: { newValue in
                        let rounded = Int((newValue / 5.0).rounded() * 5)
                        streakGoalMinutes = max(5, min(240, rounded))
                        settings.streakGoalMinutes = streakGoalMinutes
                    }
                ),
                in: 5...240,
                step: 5
            )
            .tint(RespiteTheme.pine)
            .simultaneousGesture(TapGesture().onEnded { InteractionFeedback.tap() })

            HStack(spacing: 8) {
                ForEach([15, 30, 45, 60, 90], id: \.self) { preset in
                    Button("\(preset)m") {
                        InteractionFeedback.tap()
                        streakGoalMinutes = preset
                        settings.streakGoalMinutes = preset
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(streakGoalMinutes == preset ? Color.white : textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(streakGoalMinutes == preset ? RespiteTheme.duskBlue : Color.white.opacity(0.08))
                    )
                }
                Spacer(minLength: 0)
            }

        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var focusPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus plan")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Picker("Focus plan", selection: $selectedFocusPlan) {
                ForEach(FocusPlanPreset.allCases) { plan in
                    Text(plan.title).tag(plan)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedFocusPlan.summary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)

            VStack(alignment: .leading, spacing: 8) {
                let values = selectedFocusPlan.recommendedSettings
                Text("Selected plan details")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily limit after \(values.pauseAfterMinutes)m")
                    Text("Extra Time: \(values.graceMinutes)m")
                    Text("Streak goal: \(values.streakGoalMinutes)m saved")
                    Text("Intent gate recheck: \(values.idleMinutes)m")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                )
            }

            Toggle("Enable anti-relapse windows", isOn: $antiRelapseEnabled)
                .foregroundStyle(textSecondary)
                .onChange(of: antiRelapseEnabled) { _, enabled in
                    InteractionFeedback.tap()
                    RecoveryInsightsStore.setAntiRelapseEnabled(enabled)
                    modeNoteMessage = enabled
                        ? "Anti-relapse windows enabled. Dashboard will surface your high-risk times."
                        : "Anti-relapse windows disabled."
                }

            Button("Apply focus plan") {
                InteractionFeedback.success()
                RecoveryInsightsStore.applyPlan(selectedFocusPlan, settings: settings)
                pauseMinutes = settings.pauseThresholdMinutes
                graceMinutes = settings.gracePeriodMinutes
                streakGoalMinutes = settings.streakGoalMinutes
                tiktokIdleMinutes = settings.tiktokIdleMinutesAfterExit
                restartMonitoring()
                restartTikTokUsageMonitoring()
                modeNoteMessage = "\(selectedFocusPlan.title) plan applied."
            }
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.pine)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            Text("Open your Respite shortcuts page, then create Personal Automation → App → Is Opened → Run Immediately → Add Action: “Activate Respite - intelligently shuffled”.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            ShortcutsLink(action: {
                openedShortcutsPage = true
            })
                .shortcutsLinkStyle(.automatic)

            Text("Create one automation per app.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textMuted)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var setupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup checklist")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            checklistRow(
                title: "Screen Time access granted",
                subtitle: "Needed for shields and activity monitoring",
                isDone: authorizationStatus == .approved
            )
            checklistRow(
                title: "Blocking targets selected",
                subtitle: "Apps, categories, or websites",
                isDone: hasAnyBlockingTargets
            )
            checklistRow(
                title: "Shortcuts page opened",
                subtitle: "Needed to configure Personal Automation",
                isDone: openedShortcutsPage
            )

            let doneCount = [authorizationStatus == .approved, hasAnyBlockingTargets, openedShortcutsPage].filter { $0 }.count
            Text("\(doneCount)/3 complete")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textMuted)

            Button("Complete setup") {
                InteractionFeedback.tap()
                setupChecklistCompleted = true
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RespiteTheme.duskBlue)
            )
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func checklistRow(title: String, subtitle: String, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDone ? RespiteTheme.pine : textMuted)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }

            Spacer()
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.red)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .respiteGlassCard(cornerRadius: 20)
    }

    private func infoCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .respiteGlassCard(cornerRadius: 20)
    }

    private func stepperRow(
        title: String,
        valueText: String,
        canDecrease: Bool,
        canIncrease: Bool,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text(valueText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }
            Spacer()
            HStack(spacing: 0) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 30)
                }
                .simultaneousGesture(TapGesture().onEnded { InteractionFeedback.tap() })
                .disabled(!canDecrease)

                Divider()
                    .frame(height: 18)

                Button(action: increase) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 30)
                }
                .simultaneousGesture(TapGesture().onEnded { InteractionFeedback.tap() })
                .disabled(!canIncrease)
            }
            .foregroundStyle(textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .padding(.vertical, 2)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .simultaneousGesture(TapGesture().onEnded { InteractionFeedback.tap() })
        .buttonStyle(.borderedProminent)
        .tint(RespiteTheme.pine)
    }

    private var monitoredPickerSheet: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Monitored apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            InteractionFeedback.tap()
                            loadFromStore()
                            showMonitoredPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            InteractionFeedback.success()
                            persistSelectionAndRestart(selection)
                            showMonitoredPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var intentGatePickerSheet: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $tiktokSelection)
                .navigationTitle("Intent gate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            InteractionFeedback.tap()
                            loadFromStore()
                            showIntentGatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            InteractionFeedback.success()
                            let appOverlap = tiktokSelection.applicationTokens.intersection(selection.applicationTokens)
                            let categoryOverlap = tiktokSelection.categoryTokens.intersection(selection.categoryTokens)
                            let webOverlap = tiktokSelection.webDomainTokens.intersection(selection.webDomainTokens)
                            var sanitized = tiktokSelection
                            sanitized.applicationTokens.subtract(selection.applicationTokens)
                            sanitized.categoryTokens.subtract(selection.categoryTokens)
                            sanitized.webDomainTokens.subtract(selection.webDomainTokens)
                            tiktokSelection = sanitized
                            settings.saveTikTokSelection(sanitized)
                            let overlapCount = appOverlap.count + categoryOverlap.count + webOverlap.count
                            if overlapCount > 0 {
                                modeNoteMessage = "\(overlapCount) overlapping target(s) were kept in Daily limit and removed from Intent gate."
                            } else {
                                modeNoteMessage = nil
                            }
                            restartTikTokUsageMonitoring()
                            Task { @MainActor in
                                ShieldManager.shared.reapplyAllShields()
                            }
                            showIntentGatePicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func pickerTriggerRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(textMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("Choose")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(RespiteTheme.duskBlue)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textMuted)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectionSummary(_ s: FamilyActivitySelection) -> String {
        let apps = s.applicationTokens.count
        let cats = s.categoryTokens.count
        let web = s.webDomainTokens.count
        let total = apps + cats + web
        if total == 0 {
            return "Tap Choose to pick apps"
        }
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if cats > 0 { parts.append(cats == 1 ? "1 category" : "\(cats) categories") }
        if web > 0 { parts.append(web == 1 ? "1 site" : "\(web) sites") }
        return parts.joined(separator: " · ")
    }

    private func accessRow(title: String, status: String, isEnabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isEnabled ? "checkmark.seal.fill" : "xmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isEnabled ? RespiteTheme.sageLight : textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text(status)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var screenTimeAccessLabel: String {
        switch authorizationStatus {
        case .approved: return "Approved"
        case .notDetermined: return "Not requested"
        default: return "Unavailable"
        }
    }

    private var locationAccessLabel: String {
        switch locationAuthorization {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When in use"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private var notificationAccessLabel: String {
        switch notificationAuthorization {
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private var healthKitAccessLabel: String {
        if !HealthKitMindfulnessStore.isAvailable { return "Unavailable on this device" }
        return healthKitWriteAuthorized ? "Enabled" : "Available"
    }

    private var hasAnyBlockingTargets: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty ||
        !tiktokSelection.applicationTokens.isEmpty ||
        !tiktokSelection.categoryTokens.isEmpty ||
        !tiktokSelection.webDomainTokens.isEmpty
    }

    private var reflectionReminderDateBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = reflectionReminderHour
                components.minute = reflectionReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                reflectionReminderHour = Calendar.current.component(.hour, from: newValue)
                reflectionReminderMinute = Calendar.current.component(.minute, from: newValue)
            }
        )
    }

    private var reflectionMorningDateBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = reflectionMorningHour
                components.minute = reflectionMorningMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                reflectionMorningHour = Calendar.current.component(.hour, from: newValue)
                reflectionMorningMinute = Calendar.current.component(.minute, from: newValue)
            }
        )
    }

    private var reflectionEveningDateBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = reflectionEveningHour
                components.minute = reflectionEveningMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                reflectionEveningHour = Calendar.current.component(.hour, from: newValue)
                reflectionEveningMinute = Calendar.current.component(.minute, from: newValue)
            }
        )
    }

    private var previewMode: VisualPreviewMode {
        if !useTimePreview { return .off }
        return previewAuto ? .auto : .manual
    }

    private var previewModeBinding: Binding<VisualPreviewMode> {
        Binding(
            get: { previewMode },
            set: { newMode in
                switch newMode {
                case .off:
                    useTimePreview = false
                    previewAuto = false
                case .manual:
                    useTimePreview = true
                    previewAuto = false
                case .auto:
                    useTimePreview = true
                    previewAuto = true
                }
            }
        )
    }

    private var selectedCardStyle: RespiteCardStyle {
        RespiteCardStyle(rawValue: cardStyleRaw) ?? .liquid
    }

    private var selectedCardPalette: RespiteCardPalette {
        RespiteCardPalette(rawValue: cardPaletteRaw) ?? .dayflow
    }

    private var selectedWeatherThemeMode: RespiteWeatherThemeMode {
        RespiteWeatherThemeMode(rawValue: weatherThemeModeRaw) ?? .auto
    }

    private var selectedManualWeatherCondition: DailyWeatherCondition {
        DailyWeatherCondition(rawValue: weatherThemeManualConditionRaw) ?? .partlyCloudy
    }

    private var weatherThemeModeBinding: Binding<RespiteWeatherThemeMode> {
        Binding(
            get: { selectedWeatherThemeMode },
            set: { newValue in
                InteractionFeedback.tap()
                weatherThemeModeRaw = newValue.rawValue
            }
        )
    }

    private var manualWeatherConditionBinding: Binding<DailyWeatherCondition> {
        Binding(
            get: { selectedManualWeatherCondition },
            set: { newValue in
                InteractionFeedback.tap()
                weatherThemeManualConditionRaw = newValue.rawValue
            }
        )
    }

    private var customCardTint: Color {
        Color(
            red: min(1.0, max(0.0, cardCustomRed)),
            green: min(1.0, max(0.0, cardCustomGreen)),
            blue: min(1.0, max(0.0, cardCustomBlue))
        )
    }

    private var customCardColorBinding: Binding<Color> {
        Binding(
            get: { customCardTint },
            set: { newColor in
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                if UIColor(newColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    cardCustomRed = Double(red)
                    cardCustomGreen = Double(green)
                    cardCustomBlue = Double(blue)
                }
            }
        )
    }

    private var cardStyleBinding: Binding<RespiteCardStyle> {
        Binding(
            get: { selectedCardStyle },
            set: { newValue in
                InteractionFeedback.tap()
                cardStyleRaw = newValue.rawValue
            }
        )
    }

    private var cardStyleDescription: String {
        switch selectedCardStyle {
        case .liquid:
            return "Soft blur panels for a subtle, matte glass look."
        case .frosted:
            return "Dynamic glass highlights with stronger depth and glow."
        case .opaque:
            return "Solid tinted cards with no transparency."
        }
    }

    private var formattedPreviewTime: String {
        let hour = Int(timePreviewHour) % 24
        let minutes = Int((timePreviewHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        return String(format: "%02d:%02d", hour, max(0, min(59, minutes)))
    }

    private var clampedColorIntensity: Double {
        min(1.40, max(0.35, colorIntensity))
    }

    private func loadFromStore() {
        if let stored = settings.loadSelection() {
            selection = stored
        }
        if let storedTikTok = settings.loadTikTokSelection() {
            tiktokSelection = storedTikTok
        }
        pauseMinutes = settings.pauseThresholdMinutes
        graceMinutes = settings.gracePeriodMinutes
        streakGoalMinutes = settings.streakGoalMinutes
        tiktokIdleMinutes = settings.tiktokIdleMinutesAfterExit
        selectedFocusPlan = RecoveryInsightsStore.selectedPlan()
        antiRelapseEnabled = RecoveryInsightsStore.antiRelapseEnabled()
    }

    private func persistSelectionAndRestart(_ newValue: FamilyActivitySelection) {
        let appOverlap = newValue.applicationTokens.intersection(tiktokSelection.applicationTokens)
        let categoryOverlap = newValue.categoryTokens.intersection(tiktokSelection.categoryTokens)
        let webOverlap = newValue.webDomainTokens.intersection(tiktokSelection.webDomainTokens)
        var sanitized = newValue
        sanitized.applicationTokens.subtract(tiktokSelection.applicationTokens)
        sanitized.categoryTokens.subtract(tiktokSelection.categoryTokens)
        sanitized.webDomainTokens.subtract(tiktokSelection.webDomainTokens)
        selection = sanitized
        settings.saveSelection(sanitized)
        let overlapCount = appOverlap.count + categoryOverlap.count + webOverlap.count
        if overlapCount > 0 {
            modeNoteMessage = "\(overlapCount) overlapping target(s) were kept in Intent gate and removed from Daily limit."
        } else {
            modeNoteMessage = nil
        }
        restartMonitoring()
        Task { @MainActor in
            ShieldManager.shared.reapplyAllShields()
        }
    }

    private func restartMonitoring() {
        scheduleErrorMessage = nil
        settings.dailyLimitTriggered = false
        do {
            try RegulationActivityScheduler.restartMonitoring(settings: settings)
            Task { @MainActor in
                ShieldManager.shared.reapplyAllShields()
            }
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func restartTikTokUsageMonitoring() {
        scheduleErrorMessage = nil
        do {
            try RegulationActivityScheduler.restartTikTokUsageMonitoring(settings: settings)
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func refreshPermissionStatuses() async {
        locationAuthorization = CLLocationManager.authorizationStatus()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthorization = settings.authorizationStatus
        healthKitWriteAuthorized = HealthKitMindfulnessStore.isWriteAuthorized
    }

    private func requestNotificationAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermissionStatuses()
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func requestHealthKitAuthorization() async {
        do {
            try await HealthKitMindfulnessStore.requestAuthorization()
            healthKitWriteAuthorized = HealthKitMindfulnessStore.isWriteAuthorized
            if healthKitWriteAuthorized {
                healthKitConfirmationMessage = "HealthKit mindfulness write is enabled."
            } else {
                healthKitConfirmationMessage = "HealthKit access was requested but not granted."
            }
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func scheduleReflectionReminder() async {
        await refreshPermissionStatuses()
        if !(notificationAuthorization == .authorized || notificationAuthorization == .provisional) {
            await requestNotificationAuthorization()
            await refreshPermissionStatuses()
            guard notificationAuthorization == .authorized || notificationAuthorization == .provisional else {
                scheduleErrorMessage = "Enable notifications first to schedule a daily reminder."
                reminderStatusMessage = nil
                return
            }
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "daily-reflection-reminder",
            "daily-reflection-reminder-morning",
            "daily-reflection-reminder-evening"
        ])

        do {
            if reflectionReminderMode == 2 {
                try await center.add(makeReflectionRequest(
                    identifier: "daily-reflection-reminder-morning",
                    hour: reflectionMorningHour,
                    minute: reflectionMorningMinute,
                    body: "Morning reflection: set your intention for today."
                ))
                try await center.add(makeReflectionRequest(
                    identifier: "daily-reflection-reminder-evening",
                    hour: reflectionEveningHour,
                    minute: reflectionEveningMinute,
                    body: "Evening reflection: capture your day in Reflections."
                ))
                ReflectionStore.setPromptsPerDay(2)
            } else {
                try await center.add(makeReflectionRequest(
                    identifier: "daily-reflection-reminder",
                    hour: reflectionReminderHour,
                    minute: reflectionReminderMinute,
                    body: "Take a minute to capture your day in Reflections."
                ))
                ReflectionStore.setPromptsPerDay(1)
            }
            scheduleErrorMessage = nil
            reminderStatusMessage = reflectionReminderMode == 2
                ? "Morning and evening reminders are scheduled."
                : "Reflection reminder saved for \(formattedReminderTime)."
        } catch {
            scheduleErrorMessage = error.localizedDescription
            reminderStatusMessage = nil
        }
    }

    private func makeReflectionRequest(identifier: String, hour: Int, minute: Int, body: String) -> UNNotificationRequest {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Daily reflection"
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private var formattedReminderTime: String {
        var components = DateComponents()
        components.hour = reflectionReminderHour
        components.minute = reflectionReminderMinute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetAppData() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        let sharedDefaults = UserDefaults(suiteName: RegulationAppGroup.id)
        sharedDefaults?.removePersistentDomain(forName: RegulationAppGroup.id)
        sharedDefaults?.synchronize()

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        setupChecklistCompleted = false
        openedShortcutsPage = false

        reflectionReminderHour = 21
        reflectionReminderMinute = 0
        reflectionReminderMode = 1
        reflectionMorningHour = 8
        reflectionMorningMinute = 0
        reflectionEveningHour = 21
        reflectionEveningMinute = 0

        interfaceMode = "auto"
        useTimePreview = false
        previewAuto = false
        timePreviewHour = 12.0
        colorIntensity = 0.85
        cardStyleRaw = RespiteCardStyle.liquid.rawValue
        cardPaletteRaw = RespiteCardPalette.dayflow.rawValue
        cardCustomRed = 0.30
        cardCustomGreen = 0.62
        cardCustomBlue = 0.84
        weatherThemeModeRaw = RespiteWeatherThemeMode.auto.rawValue
        weatherThemeManualConditionRaw = DailyWeatherCondition.partlyCloudy.rawValue

        scheduleErrorMessage = nil
        reminderStatusMessage = nil
        healthKitConfirmationMessage = nil
        modeNoteMessage = "App data reset. Restart app to re-run onboarding."

        Task { @MainActor in
            ShieldManager.shared.releaseShield()
            TikTokShieldManager.shared.applyShieldIfNeeded()
            try? RegulationActivityScheduler.restartMonitoring(settings: settings)
            try? RegulationActivityScheduler.restartTikTokUsageMonitoring(settings: settings)
            await refreshPermissionStatuses()
            loadFromStore()
            profileName = UserProfileStore.displayName()
            profileBirthday = UserProfileStore.birthday() ?? Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        }
    }

    private func seedDemoData() {
        let defaults = UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        interfaceMode = "auto"
        useTimePreview = true
        previewAuto = true
        timePreviewHour = 12.0
        cardStyleRaw = RespiteCardStyle.liquid.rawValue
        cardPaletteRaw = RespiteCardPalette.dayflow.rawValue
        colorIntensity = 0.35
        weatherThemeModeRaw = RespiteWeatherThemeMode.auto.rawValue
        weatherThemeManualConditionRaw = DailyWeatherCondition.partlyCloudy.rawValue

        let birthday = calendar.date(from: DateComponents(year: 2007, month: 1, day: 29))
            ?? calendar.date(byAdding: .year, value: -18, to: now)
            ?? now
        profileName = "William"
        profileBirthday = birthday
        UserProfileStore.setDisplayName(profileName)
        UserProfileStore.setBirthday(birthday)
        UserProfileStore.setProfileType(.student)
        UserProfileStore.markOnboardingCompleted()

        settings.pauseThresholdMinutes = 15
        settings.gracePeriodMinutes = 5
        settings.streakGoalMinutes = 30
        settings.tiktokIdleMinutesAfterExit = 30
        pauseMinutes = settings.pauseThresholdMinutes
        graceMinutes = settings.gracePeriodMinutes
        streakGoalMinutes = settings.streakGoalMinutes
        tiktokIdleMinutes = settings.tiktokIdleMinutesAfterExit
        selectedFocusPlan = .balanced
        antiRelapseEnabled = true
        RecoveryInsightsStore.setSelectedPlan(.balanced)
        RecoveryInsightsStore.setAntiRelapseEnabled(true)

        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.calendar = Calendar(identifier: .gregorian)
        dayKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayKeyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayKeyFormatter.dateFormat = "yyyy-MM-dd"

        var dailyHistory: [String: Int] = [:]
        for offset in 0..<21 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let key = dayKeyFormatter.string(from: day)
            let minutes: Int
            switch offset {
            case 0: minutes = 72
            case 1...6: minutes = Int.random(in: 40...95)
            default: minutes = Int.random(in: 15...90)
            }
            dailyHistory[key] = minutes
        }
        defaults.set(todayStart, forKey: "dashboard.dailyProgress.dayStamp")
        defaults.set(dailyHistory[dayKeyFormatter.string(from: todayStart)] ?? 72, forKey: "dashboard.dailyProgress.minutesSaved")
        defaults.set(dailyHistory, forKey: "dashboard.dailyProgress.history")

        var sessions: [StudyProgressStore.FocusSessionSummary] = []
        for offset in 0..<18 {
            guard let baseDay = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let sessionCount = offset < 5 ? Int.random(in: 2...3) : Int.random(in: 1...2)
            for index in 0..<sessionCount {
                let planned = [20, 25, 30, 45, 50].randomElement() ?? 25
                let endedManually = Bool.random() && offset > 1 && index == sessionCount - 1
                let completed = endedManually ? Int.random(in: max(8, planned / 3)...max(10, planned - 8)) : planned
                let endHour = 9 + (index * 3) + Int.random(in: 0...1)
                let endedAt = calendar.date(bySettingHour: min(22, endHour), minute: Int.random(in: 0...50), second: 0, of: baseDay) ?? baseDay
                let startedAt = calendar.date(byAdding: .minute, value: -completed, to: endedAt) ?? endedAt
                sessions.append(
                    StudyProgressStore.FocusSessionSummary(
                        id: UUID(),
                        startedAt: startedAt,
                        endedAt: endedAt,
                        plannedMinutes: planned,
                        completedMinutes: completed,
                        sessionType: ["Study", "Deep Work", "Revision"].randomElement() ?? "Study",
                        goal: [
                            "Finish problem set",
                            "Review class notes",
                            "Draft essay outline",
                            "Read chapter and summarize"
                        ].randomElement() ?? "Focus block",
                        endedManually: endedManually
                    )
                )
            }
        }
        sessions.sort { $0.endedAt > $1.endedAt }
        if let encodedSessions = try? JSONEncoder().encode(Array(sessions.prefix(200))) {
            defaults.set(encodedSessions, forKey: "study.progress.sessionHistory")
        }
        defaults.set(todayStart, forKey: "study.progress.dayStamp")
        defaults.set(Int.random(in: 80...150), forKey: "study.progress.focusMinutes")

        var reflections: [ReflectionEntry] = []
        for offset in 0..<12 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let period: ReflectionPeriod = offset.isMultiple(of: 2) ? .night : .afternoon
            let prompt = period == .night
                ? "What worked best for your focus today?"
                : "What is one thing you want to protect this afternoon?"
            let responseOptions = period == .night
                ? [
                    "Keeping my phone out of reach made my session smoother.",
                    "The short break between blocks helped me stay consistent.",
                    "I finished more when I focused on one task only."
                ]
                : [
                    "I will finish one task before checking social apps.",
                    "I will run a 25-minute block and then reassess.",
                    "I will protect my focus block and avoid multitasking."
                ]
            reflections.append(
                ReflectionEntry(
                    createdAt: day,
                    prompt: prompt,
                    response: responseOptions.randomElement() ?? "Stayed focused and completed my block.",
                    period: period
                )
            )
        }
        reflections.sort { $0.createdAt > $1.createdAt }
        if let encodedReflections = try? JSONEncoder().encode(reflections) {
            defaults.set(encodedReflections, forKey: "reflection.entries")
        }
        defaults.set(2, forKey: "reflection.promptsPerDay")
        defaults.set("One block at a time. Keep it clean.", forKey: "study.customEncouragement")

        scheduleErrorMessage = nil
        reminderStatusMessage = nil
        healthKitConfirmationMessage = nil
        modeNoteMessage = "Demo data seeded (Profile: William, Jan 29, 2007, Dayflow 35%)."

        Task { @MainActor in
            try? RegulationActivityScheduler.restartMonitoring(settings: settings)
            try? RegulationActivityScheduler.restartTikTokUsageMonitoring(settings: settings)
            await refreshPermissionStatuses()
            loadFromStore()
            profileName = UserProfileStore.displayName()
            profileBirthday = UserProfileStore.birthday() ?? birthday
        }
    }

    private func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }
}

private enum VisualPreviewMode: Hashable {
    case off
    case manual
    case auto
}
