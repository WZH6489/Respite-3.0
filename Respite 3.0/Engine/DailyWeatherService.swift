import Foundation
import CoreLocation
import Combine

enum DailyWeatherCondition: String, CaseIterable, Identifiable {
    case clear
    case partlyCloudy
    case cloudy
    case foggy
    case drizzle
    case rain
    case snow
    case thunderstorm
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .foggy: return "Foggy"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .thunderstorm: return "Thunderstorm"
        case .unknown: return "Default"
        }
    }

    var labelText: String {
        switch self {
        case .partlyCloudy: return "partly cloudy"
        case .thunderstorm: return "thunderstorm"
        case .clear: return "clear"
        case .cloudy: return "cloudy"
        case .foggy: return "foggy"
        case .drizzle: return "drizzle"
        case .rain: return "rain"
        case .snow: return "snow"
        case .unknown: return "partly cloudy"
        }
    }
}

@MainActor
final class DailyWeatherService: NSObject, ObservableObject {
    @Published private(set) var locationLabel: String = "Locating…"
    @Published private(set) var weatherLabel: String = "--"
    @Published private(set) var currentCondition: DailyWeatherCondition = .unknown {
        didSet {
            UserDefaults.standard.set(currentCondition.rawValue, forKey: "dev.ui.currentWeatherCondition")
        }
    }

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        UserDefaults.standard.set(currentCondition.rawValue, forKey: "dev.ui.currentWeatherCondition")
    }

    func refresh() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            locationLabel = "Location off"
            weatherLabel = "Weather unavailable"
            currentCondition = .unknown
        @unknown default:
            locationLabel = "Location unavailable"
            weatherLabel = "Weather unavailable"
            currentCondition = .unknown
        }
    }

    private func updateLocationLabel(for location: CLLocation) async {
        do {
            let places = try await geocoder.reverseGeocodeLocation(location)
            if let place = places.first {
                locationLabel = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? "Your area"
            } else {
                locationLabel = "Your area"
            }
        } catch {
            locationLabel = "Your area"
        }
    }

    private func updateWeather(for location: CLLocation) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]

        guard let url = components?.url else {
            weatherLabel = "Weather unavailable"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoCurrentResponse.self, from: data)
            let code = decoded.current.weatherCode
            let condition = weatherCondition(for: code)
            let temp = Int(decoded.current.temperature.rounded())
            currentCondition = condition
            weatherLabel = "\(condition.labelText) \(temp)°C"
        } catch {
            weatherLabel = "Weather unavailable"
            currentCondition = .unknown
        }
    }

    private func weatherCondition(for code: Int) -> DailyWeatherCondition {
        switch code {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .foggy
        case 51...67: return .drizzle
        case 71...77: return .snow
        case 80...82: return .rain
        case 95...99: return .thunderstorm
        default: return .partlyCloudy
        }
    }
}

extension DailyWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.updateLocationLabel(for: location)
            await self.updateWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locationLabel = "Location unavailable"
            self?.weatherLabel = "Weather unavailable"
            self?.currentCondition = .unknown
        }
    }
}

private struct OpenMeteoCurrentResponse: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    let current: Current
}
