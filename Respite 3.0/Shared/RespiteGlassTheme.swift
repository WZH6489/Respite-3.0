import SwiftUI

enum RespiteWeatherThemeMode: String, CaseIterable, Identifiable {
    case off
    case auto
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .auto: return "Auto"
        case .manual: return "Manual"
        }
    }
}

struct RespiteDynamicBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("dev.ui.useTimePreview") private var useTimePreview = false
    @AppStorage("dev.ui.previewAuto") private var previewAuto = false
    @AppStorage("dev.ui.timePreviewHour") private var timePreviewHour = 12.0
    @AppStorage("dev.ui.colorIntensity") private var colorIntensity = 0.85
    @AppStorage("dev.ui.cardPalette") private var cardPaletteRaw = RespiteCardPalette.dayflow.rawValue
    @AppStorage("dev.ui.cardCustomRed") private var cardCustomRed = 0.30
    @AppStorage("dev.ui.cardCustomGreen") private var cardCustomGreen = 0.62
    @AppStorage("dev.ui.cardCustomBlue") private var cardCustomBlue = 0.84
    @AppStorage("dev.ui.weatherThemeMode") private var weatherThemeModeRaw = RespiteWeatherThemeMode.auto.rawValue
    @AppStorage("dev.ui.weatherThemeManualCondition") private var weatherThemeManualConditionRaw = DailyWeatherCondition.partlyCloudy.rawValue
    @AppStorage("dev.ui.currentWeatherCondition") private var currentWeatherConditionRaw = DailyWeatherCondition.unknown.rawValue

    @StateObject private var sunTimes = SunTimesService()
    @StateObject private var dailyWeather = DailyWeatherService()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { context in
            GeometryReader { proxy in
                let date = visualDate(from: context.date)
                let accent = accentRGB
                let weather = weatherThemeCondition
                let phase = phaseGradient(for: date, intensity: clampedColorIntensity, accentRGB: accent, weatherCondition: weather)
                let t = context.date.timeIntervalSinceReferenceDate
                let driftA = sin(t / 8.0)
                let driftB = cos(t / 10.0)
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    LinearGradient(
                        colors: [
                            phase.top.opacity(0.72),
                            phase.middle.opacity(0.90),
                            phase.bottom.opacity(1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(phase.highlight.opacity(colorScheme == .dark ? 0.44 : 0.32))
                        .frame(width: width * 0.95)
                        .blur(radius: 46)
                        .offset(x: width * 0.18 * driftA, y: -height * 0.26)

                    Circle()
                        .fill(phase.accent.opacity(colorScheme == .dark ? 0.38 : 0.28))
                        .frame(width: width * 0.82)
                        .blur(radius: 40)
                        .offset(x: -width * 0.18 * driftB, y: height * 0.35)

                    LinearGradient(
                        colors: [
                            phase.highlight.opacity(0.12),
                            .clear,
                            phase.accent.opacity(0.24)
                        ],
                        startPoint: UnitPoint(x: 0.2 + (0.12 * driftA), y: 0.0),
                        endPoint: UnitPoint(x: 0.82 + (0.12 * driftB), y: 1.0)
                    )
                    .blendMode(.plusLighter)
                    .opacity(colorScheme == .dark ? 0.72 : 0.52)

                    weatherOverlay(
                        condition: weather,
                        size: proxy.size,
                        time: t
                    )

                    LinearGradient(
                        colors: [
                            .black.opacity(colorScheme == .dark ? 0.08 : 0.06),
                            .clear,
                            .black.opacity(colorScheme == .dark ? 0.13 : 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.multiply)
                }
            }
        }
        .task {
            sunTimes.refresh()
            dailyWeather.refresh()
        }
        .ignoresSafeArea()
    }

    private struct PhaseGradient {
        let top: Color
        let middle: Color
        let bottom: Color
        let highlight: Color
        let accent: Color
    }

    private var clampedColorIntensity: Double {
        min(1.40, max(0.35, colorIntensity))
    }

    private func visualDate(from source: Date) -> Date {
        guard useTimePreview else { return source }
        if previewAuto {
            return autoPreviewDate(reference: source)
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: source)
        components.hour = Int(timePreviewHour) % 24
        components.minute = Int((timePreviewHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        components.second = 0
        return Calendar.current.date(from: components) ?? source
    }

    private func autoPreviewDate(reference: Date) -> Date {
        guard let sunrise = sunTimes.sunrise, let sunset = sunTimes.sunset else {
            return reference
        }
        let sunriseHour = decimalHour(sunrise)
        let sunsetHour = decimalHour(sunset)
        let nowHour = decimalHour(reference)

        let autoHour: Double
        if nowHour < sunriseHour {
            autoHour = max(0, sunriseHour - 0.75)
        } else if nowHour > sunsetHour {
            autoHour = min(23.99, sunsetHour + 0.75)
        } else {
            autoHour = (sunriseHour + sunsetHour) / 2.0
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = Int(autoHour)
        components.minute = Int((autoHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        components.second = 0
        return Calendar.current.date(from: components) ?? reference
    }

    private func decimalHour(_ date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        return Double(hour) + (Double(minute) / 60.0)
    }

    private var accentRGB: (Double, Double, Double) {
        let palette = RespiteCardPalette(rawValue: cardPaletteRaw) ?? .dayflow
        switch palette {
        case .dayflow:
            return (0.56, 0.72, 0.40)
        case .ocean:
            return (0.29, 0.56, 0.75)
        case .forest:
            return (0.32, 0.59, 0.42)
        case .midnight:
            return (0.31, 0.34, 0.41)
        case .custom:
            return (
                min(1.0, max(0.0, cardCustomRed)),
                min(1.0, max(0.0, cardCustomGreen)),
                min(1.0, max(0.0, cardCustomBlue))
            )
        }
    }

    private var weatherThemeCondition: DailyWeatherCondition {
        let mode = RespiteWeatherThemeMode(rawValue: weatherThemeModeRaw) ?? .auto
        switch mode {
        case .off:
            return .unknown
        case .auto:
            return dailyWeather.currentCondition
        case .manual:
            return DailyWeatherCondition(rawValue: weatherThemeManualConditionRaw) ?? .partlyCloudy
        }
    }

    private func mix(_ base: Double, _ accent: Double, amount: Double) -> Double {
        (base * (1.0 - amount)) + (accent * amount)
    }

    private func phaseGradient(
        for date: Date,
        intensity: Double,
        accentRGB: (Double, Double, Double),
        weatherCondition: DailyWeatherCondition
    ) -> PhaseGradient {
        let hour = Calendar.current.component(.hour, from: date)
        let warm = max(0.0, min(1.0, (sin((Double(hour) / 24.0) * .pi * 2 - .pi / 2) + 1) / 2))

        func adjusted(_ value: Double) -> Double {
            let centered = value - 0.5
            return min(1.0, max(0.0, 0.5 + (centered * intensity)))
        }

        let (accentR, accentG, accentB) = accentRGB
        let (weatherR, weatherG, weatherB, weatherWeight) = weatherTone(for: weatherCondition)

        return PhaseGradient(
            top: Color(
                red: adjusted(mix(mix(0.08 + 0.20 * warm, accentR, amount: 0.22), weatherR, amount: weatherWeight * 0.60)),
                green: adjusted(mix(mix(0.18 + 0.22 * warm, accentG, amount: 0.22), weatherG, amount: weatherWeight * 0.60)),
                blue: adjusted(mix(mix(0.30 - 0.16 * warm, accentB, amount: 0.22), weatherB, amount: weatherWeight * 0.60))
            ),
            middle: Color(
                red: adjusted(mix(mix(0.12 + 0.26 * warm, accentR, amount: 0.30), weatherR, amount: weatherWeight * 0.75)),
                green: adjusted(mix(mix(0.30 + 0.24 * warm, accentG, amount: 0.30), weatherG, amount: weatherWeight * 0.75)),
                blue: adjusted(mix(mix(0.48 - 0.28 * warm, accentB, amount: 0.30), weatherB, amount: weatherWeight * 0.75))
            ),
            bottom: Color(
                red: adjusted(mix(mix(0.18 + 0.30 * warm, accentR, amount: 0.36), weatherR, amount: weatherWeight)),
                green: adjusted(mix(mix(0.38 + 0.20 * warm, accentG, amount: 0.36), weatherG, amount: weatherWeight)),
                blue: adjusted(mix(mix(0.70 - 0.42 * warm, accentB, amount: 0.36), weatherB, amount: weatherWeight))
            ),
            highlight: Color(
                red: adjusted(mix(mix(0.48 + 0.42 * warm, accentR, amount: 0.40), weatherR, amount: weatherWeight * 0.85)),
                green: adjusted(mix(mix(0.52 + 0.20 * warm, accentG, amount: 0.40), weatherG, amount: weatherWeight * 0.85)),
                blue: adjusted(mix(mix(0.44 - 0.28 * warm, accentB, amount: 0.40), weatherB, amount: weatherWeight * 0.85))
            ),
            accent: Color(
                red: adjusted(mix(mix(0.24 + 0.16 * warm, accentR, amount: 0.50), weatherR, amount: weatherWeight)),
                green: adjusted(mix(mix(0.50 + 0.14 * warm, accentG, amount: 0.50), weatherG, amount: weatherWeight)),
                blue: adjusted(mix(mix(0.82 - 0.40 * warm, accentB, amount: 0.50), weatherB, amount: weatherWeight))
            )
        )
    }

    @ViewBuilder
    private func weatherOverlay(condition: DailyWeatherCondition, size: CGSize, time: TimeInterval) -> some View {
        switch condition {
        case .drizzle:
            rainLayer(size: size, time: time, count: 24, speed: 0.12, opacity: 0.16, length: 14)
        case .rain:
            rainLayer(size: size, time: time, count: 34, speed: 0.20, opacity: 0.25, length: 20)
        case .thunderstorm:
            ZStack {
                rainLayer(size: size, time: time, count: 42, speed: 0.24, opacity: 0.30, length: 22)
                Color.white
                    .opacity(stormFlashOpacity(time: time))
                    .blendMode(.screen)
            }
        case .snow:
            snowLayer(size: size, time: time)
        case .foggy:
            ZStack {
                fogLayer(size: size, time: time, opacity: 0.42)
                cloudLayer(size: size, time: time, opacity: 0.14)
                Color.white.opacity(0.07)
            }
        case .cloudy:
            ZStack {
                cloudLayer(size: size, time: time, opacity: 0.38)
                fogLayer(size: size, time: time, opacity: 0.22)
                Color.black.opacity(0.06)
            }
        case .partlyCloudy:
            ZStack {
                sunGlow(size: size, time: time)
                cloudLayer(size: size, time: time, opacity: 0.30)
            }
        case .clear:
            ZStack {
                sunGlow(size: size, time: time)
                Color.white.opacity(0.02)
            }
        case .unknown:
            EmptyView()
        }
    }

    private func rainLayer(
        size: CGSize,
        time: TimeInterval,
        count: Int,
        speed: Double,
        opacity: Double,
        length: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let seed = weatherSeed(index)
                let alt = weatherSeed(index + 301)
                let depth = weatherSeed(index + 907)

                let fallSpeed = speed * (0.65 + (seed * 0.95))
                let wobble = sin((time * (0.45 + depth)) + (seed * 19.0)) * 0.06
                let yPhase = (time * fallSpeed) + (alt * 1.9) + wobble
                let y = CGFloat(yPhase.truncatingRemainder(dividingBy: 1.0)) * (size.height + 70) - 35

                let swayA = sin((time * (0.7 + alt)) + (seed * 14.0)) * (2 + depth * 10)
                let swayB = cos((time * (0.35 + seed)) + (alt * 11.0)) * (1 + depth * 5)
                let x = (seed * size.width) + CGFloat(swayA + swayB)

                let dropLength = (length * 0.62) + CGFloat((alt * 6).rounded())
                let dropWidth = 0.55 + (depth * 0.95)
                let angle = 6 + (alt * 26)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(opacity * (0.70 + (depth * 0.45))))
                    .frame(width: dropWidth, height: dropLength)
                    .rotationEffect(.degrees(angle))
                    .position(x: x, y: y)
            }
        }
        .blur(radius: 1.1)
    }

    private func snowLayer(size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<30, id: \.self) { index in
                let seed = weatherSeed(index)
                let speed = 0.085 + (seed * 0.055)
                let yPhase = (time * speed) + seed
                let y = CGFloat(yPhase.truncatingRemainder(dividingBy: 1.0)) * (size.height + 40) - 20
                let xDrift = sin((time * 0.45) + (seed * 16.0)) * 24
                let x = CGFloat(seed) * size.width + CGFloat(xDrift)
                Circle()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: 2 + (seed * 2.8), height: 2 + (seed * 2.8))
                    .position(x: x, y: y)
            }
        }
        .blur(radius: 0.2)
    }

    private func fogLayer(size: CGSize, time: TimeInterval, opacity: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: size.width * 1.05)
                .blur(radius: 40)
                .offset(x: CGFloat(sin(time * 0.24) * 52), y: -size.height * 0.08)

            Circle()
                .fill(Color.white.opacity(opacity * 0.8))
                .frame(width: size.width * 0.95)
                .blur(radius: 36)
                .offset(x: CGFloat(cos(time * 0.20) * 60), y: size.height * 0.18)
        }
    }

    private func cloudLayer(size: CGSize, time: TimeInterval, opacity: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(opacity))
                .frame(width: size.width * 0.72, height: size.width * 0.24)
                .blur(radius: 20)
                .offset(x: CGFloat(sin(time * 0.18) * 68), y: -size.height * 0.12)

            Ellipse()
                .fill(Color.white.opacity(opacity * 0.85))
                .frame(width: size.width * 0.62, height: size.width * 0.21)
                .blur(radius: 18)
                .offset(x: CGFloat(cos(time * 0.15) * 60), y: size.height * 0.08)
        }
    }

    private func sunGlow(size: CGSize, time: TimeInterval) -> some View {
        let pulse = 0.90 + (0.10 * sin(time * 0.28))
        let driftX = sin(time * 0.11) * 18
        let driftY = cos(time * 0.09) * 8

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.93, blue: 0.70).opacity(0.34),
                            Color(red: 1.0, green: 0.93, blue: 0.70).opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.40
                    )
                )
                .frame(width: (size.width * 0.64) * pulse, height: (size.width * 0.56) * pulse)
                .blur(radius: 8)

            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) * 25.0 + (sin(time * 0.18 + Double(index)) * 8.0)
                Capsule(style: .continuous)
                    .fill(Color(red: 1.0, green: 0.92, blue: 0.72).opacity(0.12))
                    .frame(width: size.width * 0.30, height: 18)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(angle))
            }
        }
        .offset(x: (size.width * 0.24) + driftX, y: (-size.height * 0.30) + driftY)
    }

    private func stormFlashOpacity(time: TimeInterval) -> Double {
        let pulseA = pow(max(0.0, sin(time * 1.6)), 26)
        let pulseB = pow(max(0.0, sin((time * 1.05) + 1.7)), 34)
        return min(0.22, (pulseA * 0.22) + (pulseB * 0.16))
    }

    private func weatherSeed(_ index: Int) -> Double {
        let value = sin(Double(index + 1) * 12.9898) * 43758.5453
        return value - floor(value)
    }

    private func weatherTone(for condition: DailyWeatherCondition) -> (Double, Double, Double, Double) {
        switch condition {
        case .clear:
            return (0.98, 0.83, 0.52, 0.14)
        case .partlyCloudy:
            return (0.78, 0.82, 0.86, 0.08)
        case .cloudy:
            return (0.64, 0.70, 0.78, 0.16)
        case .foggy:
            return (0.70, 0.74, 0.76, 0.20)
        case .drizzle:
            return (0.52, 0.64, 0.78, 0.22)
        case .rain:
            return (0.44, 0.56, 0.74, 0.26)
        case .snow:
            return (0.86, 0.90, 0.96, 0.18)
        case .thunderstorm:
            return (0.30, 0.38, 0.54, 0.32)
        case .unknown:
            return (0.0, 0.0, 0.0, 0.0)
        }
    }
}

enum RespiteCardStyle: String, CaseIterable {
    case liquid
    case frosted
    case opaque

    var title: String {
        switch self {
        case .liquid: return "Liquid"
        case .frosted: return "Frosted"
        case .opaque: return "Opaque"
        }
    }
}

enum RespiteCardPalette: String, CaseIterable {
    case dayflow
    case ocean
    case forest
    case midnight
    case custom

    var title: String {
        switch self {
        case .dayflow: return "Dayflow"
        case .ocean: return "Blue"
        case .forest: return "Green"
        case .midnight: return "Midnight"
        case .custom: return "Custom"
        }
    }

    var tint: Color {
        switch self {
        case .dayflow: return Color(red: 0.56, green: 0.72, blue: 0.40)
        case .ocean: return Color(red: 0.29, green: 0.56, blue: 0.75)
        case .forest: return Color(red: 0.32, green: 0.59, blue: 0.42)
        case .midnight: return Color(red: 0.31, green: 0.34, blue: 0.41)
        case .custom: return Color(red: 0.29, green: 0.56, blue: 0.75)
        }
    }
}

private struct RespiteGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    @AppStorage("dev.ui.cardStyle") private var cardStyleRaw = RespiteCardStyle.liquid.rawValue
    @AppStorage("dev.ui.cardPalette") private var cardPaletteRaw = RespiteCardPalette.dayflow.rawValue
    @AppStorage("dev.ui.cardCustomRed") private var cardCustomRed = 0.30
    @AppStorage("dev.ui.cardCustomGreen") private var cardCustomGreen = 0.62
    @AppStorage("dev.ui.cardCustomBlue") private var cardCustomBlue = 0.84
    @AppStorage("dev.ui.weatherThemeMode") private var weatherThemeModeRaw = RespiteWeatherThemeMode.auto.rawValue
    @AppStorage("dev.ui.weatherThemeManualCondition") private var weatherThemeManualConditionRaw = DailyWeatherCondition.partlyCloudy.rawValue
    @AppStorage("dev.ui.currentWeatherCondition") private var currentWeatherConditionRaw = DailyWeatherCondition.unknown.rawValue

    @ViewBuilder
    func body(content: Content) -> some View {
        let style = RespiteCardStyle(rawValue: cardStyleRaw) ?? .liquid
        let palette = RespiteCardPalette(rawValue: cardPaletteRaw) ?? .dayflow
        let customTint = Color(
            red: min(1.0, max(0.0, cardCustomRed)),
            green: min(1.0, max(0.0, cardCustomGreen)),
            blue: min(1.0, max(0.0, cardCustomBlue))
        )

        let styleTint: Color = {
            switch style {
            case .liquid, .frosted:
                switch palette {
                case .dayflow:
                    return Color(red: 0.56, green: 0.72, blue: 0.40)
                case .ocean:
                    return Color(red: 0.28, green: 0.56, blue: 0.76)
                case .forest:
                    return Color(red: 0.31, green: 0.58, blue: 0.41)
                case .midnight:
                    return Color(red: 0.34, green: 0.36, blue: 0.42)
                case .custom:
                    return customTint
                }
            case .opaque:
                switch palette {
                case .dayflow:
                    return colorScheme == .dark
                        ? Color(red: 0.27, green: 0.32, blue: 0.22)
                        : Color(red: 0.82, green: 0.87, blue: 0.74)
                case .ocean:
                    return colorScheme == .dark
                        ? Color(red: 0.20, green: 0.27, blue: 0.33)
                        : Color(red: 0.76, green: 0.81, blue: 0.86)
                case .forest:
                    return colorScheme == .dark
                        ? Color(red: 0.20, green: 0.29, blue: 0.24)
                        : Color(red: 0.78, green: 0.84, blue: 0.79)
                case .midnight:
                    return colorScheme == .dark
                        ? Color(red: 0.15, green: 0.18, blue: 0.22)
                        : Color(red: 0.73, green: 0.76, blue: 0.81)
                case .custom:
                    return customTint
                }
            }
        }()

        if #available(iOS 26.0, *) {
            content
                .background {
                    switch style {
                    case .liquid:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint.opacity(colorScheme == .dark ? 0.11 : 0.08))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.14), lineWidth: 1)
                            )
                    case .frosted:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint.opacity(colorScheme == .dark ? 0.07 : 0.05))
                            .glassEffect(.regular.tint(styleTint.opacity(colorScheme == .dark ? 0.14 : 0.10)).interactive(false), in: .rect(cornerRadius: cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.26), lineWidth: 1)
                            )
                    case .opaque:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
                            )
                    }
                }
        } else {
            content
                .background {
                    switch style {
                    case .liquid:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint.opacity(colorScheme == .dark ? 0.10 : 0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.14), lineWidth: 1)
                            )
                    case .frosted:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint.opacity(colorScheme == .dark ? 0.06 : 0.045))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.26), lineWidth: 1)
                            )
                    case .opaque:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(styleTint)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
                            )
                    }
                }
        }
    }
}

extension View {
    func respiteGlassCard(cornerRadius: CGFloat) -> some View {
        modifier(RespiteGlassCardModifier(cornerRadius: cornerRadius))
    }
}
