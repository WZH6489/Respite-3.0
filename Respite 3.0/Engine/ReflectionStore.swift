import Foundation

struct ReflectionEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let prompt: String
    let response: String
    let period: ReflectionPeriod

    init(id: UUID = UUID(), createdAt: Date = .now, prompt: String, response: String, period: ReflectionPeriod) {
        self.id = id
        self.createdAt = createdAt
        self.prompt = prompt
        self.response = response
        self.period = period
    }
}

enum ReflectionPeriod: String, Codable, CaseIterable {
    case afternoon
    case night

    var title: String {
        switch self {
        case .afternoon: return "Afternoon"
        case .night: return "Night"
        }
    }
}

enum ReflectionStore {
    private static let entriesKey = "reflection.entries"
    private static let promptsPerDayKey = "reflection.promptsPerDay"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func promptsPerDay() -> Int {
        let value = defaults.integer(forKey: promptsPerDayKey)
        return value == 2 ? 2 : 1
    }

    static func setPromptsPerDay(_ value: Int) {
        defaults.set(value == 2 ? 2 : 1, forKey: promptsPerDayKey)
    }

    static func allEntries() -> [ReflectionEntry] {
        guard let data = defaults.data(forKey: entriesKey),
              let entries = try? JSONDecoder().decode([ReflectionEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    static func addEntry(prompt: String, response: String, period: ReflectionPeriod) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var entries = allEntries()
        entries.insert(ReflectionEntry(prompt: prompt, response: trimmed, period: period), at: 0)
        save(entries: Array(entries.prefix(200)))
    }

    static func deleteEntry(id: UUID) {
        var entries = allEntries()
        entries.removeAll { $0.id == id }
        save(entries: entries)
    }

    static func updateEntry(id: UUID, prompt: String, response: String, period: ReflectionPeriod) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entries = allEntries()
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let existing = entries[index]
        entries[index] = ReflectionEntry(
            id: existing.id,
            createdAt: existing.createdAt,
            prompt: prompt,
            response: trimmed,
            period: period
        )
        save(entries: entries)
    }

    private static func save(entries: [ReflectionEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: entriesKey)
        }
    }
}
