import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ReflectionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var responseText: String = ""
    @State private var customPromptText: String = ""
    @State private var entries: [ReflectionEntry] = ReflectionStore.allEntries()
    @State private var selectedPrompt: String = ""
    @State private var editingEntry: ReflectionEntry?
    @State private var editingText: String = ""

    @FocusState private var isEditorFocused: Bool
    @FocusState private var isEditingFocused: Bool
    @AppStorage("reflection.focusPromptSuggestion") private var focusPromptSuggestion = ""

    private var textPrimary: Color { .primary }
    private var textSecondary: Color { .secondary }
    private var textMuted: Color { .secondary.opacity(0.9) }

    private var todayMinutes: Int { DailyProgressStore.minutesSavedToday() }
    private var yearMinutes: Int { DailyProgressStore.projectedYearMinutes() }
    private var lifetimeMinutes: Int { DailyProgressStore.projectedLifetimeMinutes(lifespanYears: 80) }
    private var trendDelta: Int { DailyProgressStore.weeklyTrendDeltaMinutes() }

    private let promptPool: [String] = [
        "What felt most intentional about your phone use today?",
        "When did your usage feel automatic instead of deliberate?",
        "What moment today made you feel most present offline?",
        "Which app pulled you in the longest, and why?",
        "What boundary worked well for you today?",
        "What would tomorrow's healthier screen habit look like?",
        "When did you choose calm over impulse today?",
        "What trigger most often starts a distracting session for you?",
        "What is one small change that would protect your attention tomorrow?"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    impactCard
                    consistencyCard
                    reflectionIntelligenceCard
                    reflectionComposerCard
                    recentEntriesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .respiteTrackBottomBarScroll()
            .contentShape(Rectangle())
            .onTapGesture { isEditorFocused = false }
            .background(RespiteDynamicBackground())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditorFocused = false }
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            editSheet(entry)
        }
        .onAppear {
            refreshEntries()
            if selectedPrompt.isEmpty {
                selectedPrompt = promptPool.first ?? ""
            }
            if !focusPromptSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedPrompt = focusPromptSuggestion
            }
        }
    }

    private var titleBlock: some View {
        Text("Daily reflections")
            .font(.system(size: 34, weight: .semibold, design: .default))
            .foregroundStyle(textPrimary)
    }

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your time impact")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)
                Spacer()
                trendChip
            }

            HStack(spacing: 10) {
                metricTile(title: "Today", value: formatMinutes(todayMinutes), subtitle: "saved")
                metricTile(title: "This pace, 1 year", value: formatDaysHours(yearMinutes), subtitle: "saved")
            }

            metricTile(title: "Typical lifetime (80y pace)", value: formatLongDuration(lifetimeMinutes), subtitle: "saved")
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var trendChip: some View {
        let up = trendDelta >= 0
        return HStack(spacing: 6) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
            Text(up ? "Gaining time back" : "Losing time")
                .font(.system(size: 12, weight: .semibold, design: .default))
        }
        .foregroundStyle(up ? RespiteTheme.sageLight : RespiteTheme.berryAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.10)))
    }

    private func metricTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(textMuted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.06 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.18), lineWidth: 1)
                    )
            )
    }

    private var reflectionIntelligenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reflection intelligence")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(textSecondary)

            Text(weeklyReflectionSummary)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)

            if topReflectionThemes.isEmpty {
                Text("Write a few reflections to unlock theme trends.")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(textMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(topReflectionThemes, id: \.self) { theme in
                            Text(theme)
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundStyle(RespiteTheme.pine)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(RespiteTheme.duskBlue.opacity(0.10))
                                )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var reflectionComposerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's reflection")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(textSecondary)

            HStack(alignment: .top, spacing: 10) {
                Text(selectedPrompt)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button("Reshuffle") {
                    reshufflePrompts()
                }
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.10)))
            }

            if !focusPromptSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 8) {
                    Text("Focus follow-up ready")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(RespiteTheme.pine)
                    Spacer()
                    Button("Use") {
                        selectedPrompt = focusPromptSuggestion
                    }
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(textPrimary)
                    Button("Clear") {
                        focusPromptSuggestion = ""
                    }
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RespiteTheme.duskBlue.opacity(0.10))
                )
            }

            TextField("Or write your own prompt", text: $customPromptText)
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.06 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                        )
                )

            TextEditor(text: $responseText)
                .focused($isEditorFocused)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .foregroundStyle(textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.06 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                        )
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    starterChip("Today I noticed that…")
                    starterChip("A trigger I want to handle better is…")
                    starterChip("Tomorrow I will protect focus by…")
                    starterChip("What helped most was…")
                }
            }

            Button {
                InteractionFeedback.success()
                let chosenPrompt = customPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
                ReflectionStore.addEntry(
                    prompt: chosenPrompt.isEmpty ? selectedPrompt : chosenPrompt,
                    response: responseText,
                    period: suggestedPeriod()
                )
                responseText = ""
                customPromptText = ""
                focusPromptSuggestion = ""
                isEditorFocused = false
                dismissKeyboard()
                refreshEntries()
            } label: {
                Text("Save reflection")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(RespiteTheme.pine))
            }
            .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reflection consistency")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("\(reflectionStreakDays)d streak")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(RespiteTheme.pine)
            }

            Text("This week: \(reflectionsThisWeek)/\(weeklyReflectionTarget)")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(textMuted)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(RespiteTheme.pine.opacity(0.80))
                        .frame(width: proxy.size.width * weeklyCadenceProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var recentEntriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reflection archive")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("Progress: \(reflectionsThisWeek) this week")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(RespiteTheme.pine)
            }

            if groupedEntries.isEmpty {
                Text("No reflections yet. Add one above.")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textMuted)
            } else {
                List {
                    ForEach(ReflectionEntryCategory.allCases, id: \.self) { category in
                        if let categoryEntries = groupedEntries[category], !categoryEntries.isEmpty {
                            Section(category.title) {
                                ForEach(categoryEntries.prefix(5)) { entry in
                                    ReflectionRowCard(
                                        entry: entry,
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary,
                                        textMuted: textMuted,
                                        onDelete: {
                                            ReflectionStore.deleteEntry(id: entry.id)
                                            refreshEntries()
                                        },
                                        onEdit: {
                                            editingEntry = entry
                                            editingText = entry.response
                                        },
                                        onOpen: {
                                            editingEntry = entry
                                            editingText = entry.response
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            ReflectionStore.deleteEntry(id: entry.id)
                                            refreshEntries()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 470)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func editSheet(_ entry: ReflectionEntry) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.prompt)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(RespiteTheme.textPrimary)

                TextEditor(text: $editingText)
                    .focused($isEditingFocused)
                    .frame(minHeight: 180)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RespiteTheme.surfaceSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RespiteTheme.border, lineWidth: 1)
                            )
                    )

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RespiteTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Edit reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingEntry = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        InteractionFeedback.success()
                        ReflectionStore.updateEntry(
                            id: entry.id,
                            prompt: entry.prompt,
                            response: editingText,
                            period: entry.period
                        )
                        editingEntry = nil
                        refreshEntries()
                    }
                    .fontWeight(.semibold)
                    .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isEditingFocused = true
                }
            }
        }
    }

    private var groupedEntries: [ReflectionEntryCategory: [ReflectionEntry]] {
        Dictionary(grouping: entries.prefix(24)) { entry in
            category(for: entry.createdAt)
        }
    }

    private func category(for date: Date) -> ReflectionEntryCategory {
        if Calendar.current.isDateInToday(date) { return .today }
        if Calendar.current.isDate(date, equalTo: .now, toGranularity: .weekOfYear) { return .thisWeek }
        return .earlier
    }

    private func reshufflePrompts() {
        guard !promptPool.isEmpty else {
            selectedPrompt = ""
            return
        }
        var candidate = promptPool.randomElement() ?? ""
        if promptPool.count > 1 {
            while candidate == selectedPrompt {
                candidate = promptPool.randomElement() ?? candidate
            }
        }
        selectedPrompt = candidate
    }

    private func refreshEntries() {
        entries = ReflectionStore.allEntries()
    }

    private func starterChip(_ text: String) -> some View {
        Button(text) {
            InteractionFeedback.tap()
            if responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                responseText = text + " "
            } else {
                responseText += (responseText.hasSuffix(" ") ? "" : " ") + text + " "
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .default))
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(RespiteTheme.duskBlue.opacity(0.10))
        )
    }

    private var topReflectionThemes: [String] {
        let keywords: [String: [String]] = [
            "Focus": ["focus", "study", "task", "deep work", "attention"],
            "Triggers": ["trigger", "urge", "impulse", "bored", "scroll"],
            "Boundaries": ["boundary", "limit", "blocked", "timer", "plan"],
            "Mood": ["stress", "anxious", "calm", "tired", "energy"],
            "Wins": ["win", "better", "improved", "success", "proud"]
        ]

        let recentText = entries.prefix(20).map { ($0.prompt + " " + $0.response).lowercased() }
        var counts: [String: Int] = [:]
        for (theme, words) in keywords {
            let hits = recentText.reduce(0) { running, line in
                running + (words.contains { line.contains($0) } ? 1 : 0)
            }
            if hits > 0 {
                counts[theme] = hits
            }
        }

        return counts
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .prefix(3)
            .map { $0.key }
    }

    private var weeklyReflectionSummary: String {
        if reflectionsThisWeek == 0 {
            return "No reflections this week yet. One short note today can reset momentum."
        }

        let themeText = topReflectionThemes.isEmpty ? "Your consistency is improving." : "Top themes: " + topReflectionThemes.joined(separator: ", ") + "."
        return "\(reflectionsThisWeek) reflections this week with a \(reflectionStreakDays)-day streak. \(themeText)"
    }

    private var reflectionsThisWeek: Int {
        entries.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .weekOfYear) }.count
    }

    private var weeklyReflectionTarget: Int {
        ReflectionStore.promptsPerDay() == 2 ? 8 : 4
    }

    private var weeklyCadenceProgress: Double {
        min(1.0, Double(reflectionsThisWeek) / Double(max(1, weeklyReflectionTarget)))
    }

    private var reflectionStreakDays: Int {
        let byDay = Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) })
        var days = 0
        var cursor = Calendar.current.startOfDay(for: .now)
        while byDay.contains(cursor) {
            days += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return days
    }

    private func suggestedPeriod(now: Date = .now) -> ReflectionPeriod {
        let hour = Calendar.current.component(.hour, from: now)
        return hour < 18 ? .afternoon : .night
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatMinutes(_ value: Int) -> String {
        if value < 60 { return "\(value)m" }
        let hours = value / 60
        let minutes = value % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    private func formatDaysHours(_ value: Int) -> String {
        let totalHours = max(0, value) / 60
        let days = totalHours / 24
        let hours = totalHours % 24
        return "\(days)d \(hours)h"
    }

    private func formatLongDuration(_ totalMinutes: Int) -> String {
        let days = totalMinutes / (60 * 24)
        if days >= 365 {
            let years = Double(days) / 365.0
            return String(format: "%.1f years", years)
        }
        if days >= 30 {
            let months = Double(days) / 30.0
            return String(format: "%.1f months", months)
        }
        return "\(days) days"
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

private struct ReflectionRowCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ReflectionEntry
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.period.title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(RespiteTheme.mistBlue)
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textMuted)
                }
                Text(dateString(entry.createdAt))
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(textMuted)
            }
            Text(entry.prompt)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
            Text(entry.response)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(textSecondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.05 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.14), lineWidth: 1)
                )
        )
        .onLongPressGesture(minimumDuration: 0.45) {
            onEdit()
        }
        .onTapGesture {
            onOpen()
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private enum ReflectionEntryCategory: CaseIterable {
    case today
    case thisWeek
    case earlier

    var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .earlier: return "Earlier"
        }
    }
}
