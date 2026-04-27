import Foundation
import HealthKit

enum HealthKitMindfulnessStore {
    enum MindfulnessError: LocalizedError {
        case unavailable
        case missingPrivacyKeys

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Health data is not available on this device."
            case .missingPrivacyKeys:
                return "Health access strings are missing from app settings."
            }
        }
    }

    private static let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the user has already granted Respite permission to write
    /// mindful-session samples. `sharingAuthorized` is the only status iOS
    /// can accurately report for share-only types; `notDetermined` and
    /// `sharingDenied` both mean we still need to (re)prompt.
    static var isWriteAuthorized: Bool {
        guard isAvailable,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else { return false }
        return store.authorizationStatus(for: mindful) == .sharingAuthorized
    }

    static func requestAuthorization() async throws {
        guard isAvailable else { throw MindfulnessError.unavailable }
        guard hasRequiredPrivacyKeys else { throw MindfulnessError.missingPrivacyKeys }
        guard let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        try await store.requestAuthorization(toShare: [mindful], read: [mindful])
    }

    static func writeMindfulness(minutes: Int) async throws {
        guard isAvailable, minutes > 0 else { return }
        guard hasRequiredPrivacyKeys else { throw MindfulnessError.missingPrivacyKeys }
        guard let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let end = Date()
        let start = Calendar.current.date(byAdding: .minute, value: -minutes, to: end) ?? end
        let sample = HKCategorySample(
            type: mindful,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        try await requestAuthorization()
        try await store.save(sample)
    }

    private static var hasRequiredPrivacyKeys: Bool {
        let share = Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String
        let update = Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") as? String
        return !(share?.isEmpty ?? true) && !(update?.isEmpty ?? true)
    }
}
