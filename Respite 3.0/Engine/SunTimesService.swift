import Foundation
import CoreLocation
import Combine

@MainActor
final class SunTimesService: NSObject, ObservableObject {
    @Published private(set) var sunrise: Date?
    @Published private(set) var sunset: Date?
    @Published private(set) var lastUpdated: Date?

    private let locationManager = CLLocationManager()
    private let decoder = JSONDecoder()

    private enum StorageKeys {
        static let sunrise = "sunTimes.cached.sunrise"
        static let sunset = "sunTimes.cached.sunset"
        static let lastUpdated = "sunTimes.cached.lastUpdated"
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
        loadCachedTimes()
    }

    func refresh() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func fetchSunTimes(latitude: Double, longitude: Double) async {
        var components = URLComponents(string: "https://api.sunrise-sunset.org/json")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "formatted", value: "0")
        ]

        guard let url = components?.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(SunTimesResponse.self, from: data)
            guard response.status == "OK" else { return }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let sunriseDate = formatter.date(from: response.results.sunrise)
                ?? ISO8601DateFormatter().date(from: response.results.sunrise)
            let sunsetDate = formatter.date(from: response.results.sunset)
                ?? ISO8601DateFormatter().date(from: response.results.sunset)

            guard let sunriseDate, let sunsetDate else { return }

            sunrise = sunriseDate
            sunset = sunsetDate
            lastUpdated = Date()
            cacheTimes()
        } catch {
            // Keep last cached values on transient network failures.
        }
    }

    private func cacheTimes() {
        let defaults = UserDefaults.standard
        defaults.set(sunrise, forKey: StorageKeys.sunrise)
        defaults.set(sunset, forKey: StorageKeys.sunset)
        defaults.set(lastUpdated, forKey: StorageKeys.lastUpdated)
    }

    private func loadCachedTimes() {
        let defaults = UserDefaults.standard
        sunrise = defaults.object(forKey: StorageKeys.sunrise) as? Date
        sunset = defaults.object(forKey: StorageKeys.sunset) as? Date
        lastUpdated = defaults.object(forKey: StorageKeys.lastUpdated) as? Date
    }
}

extension SunTimesService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            await self?.fetchSunTimes(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep cached values if location fails.
    }
}

private struct SunTimesResponse: Decodable {
    struct Results: Decodable {
        let sunrise: String
        let sunset: String
    }

    let results: Results
    let status: String
}
