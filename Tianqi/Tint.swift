import SwiftUI

struct WeatherTint {
    var top: Color
    var bottom: Color
    var ink: Color
    var secondary: Color
    var chip: Color
    var onInk: Color
    var darkBackdrop: Bool

    static let paper = WeatherTint(
        top: Color(red: 0.965, green: 0.941, blue: 0.902),
        bottom: Color(red: 0.902, green: 0.847, blue: 0.765),
        ink: Color(red: 0.176, green: 0.145, blue: 0.114),
        secondary: Color(red: 0.176, green: 0.145, blue: 0.114).opacity(0.58),
        chip: Color.white.opacity(0.45),
        onInk: Color(red: 0.980, green: 0.965, blue: 0.937),
        darkBackdrop: false
    )

    static func resolve(code: Int, isDay: Bool) -> WeatherTint {
        if !isDay {
            return night(Sky.group(code))
        }
        switch Sky.group(code) {
        case .clear, .partly:
            return day(
                top: (0.984, 0.902, 0.784),
                bottom: (0.933, 0.745, 0.545),
                ink: (0.180, 0.133, 0.090)
            )
        case .cloudy:
            return day(
                top: (0.878, 0.886, 0.875),
                bottom: (0.710, 0.737, 0.733),
                ink: (0.153, 0.169, 0.165)
            )
        case .fog:
            return day(
                top: (0.910, 0.890, 0.847),
                bottom: (0.753, 0.729, 0.675),
                ink: (0.188, 0.165, 0.137)
            )
        case .rain:
            return day(
                top: (0.761, 0.831, 0.843),
                bottom: (0.545, 0.659, 0.698),
                ink: (0.102, 0.157, 0.176)
            )
        case .snow:
            return day(
                top: (0.925, 0.945, 0.957),
                bottom: (0.753, 0.824, 0.875),
                ink: (0.133, 0.169, 0.204)
            )
        case .thunder:
            return WeatherTint(
                top: Color(red: 0.404, green: 0.420, blue: 0.490),
                bottom: Color(red: 0.227, green: 0.243, blue: 0.306),
                ink: Color(red: 0.961, green: 0.941, blue: 0.902),
                secondary: Color(red: 0.961, green: 0.941, blue: 0.902).opacity(0.68),
                chip: Color.white.opacity(0.10),
                onInk: Color(red: 0.165, green: 0.169, blue: 0.196),
                darkBackdrop: true
            )
        }
    }

    private static func night(_ sky: Sky) -> WeatherTint {
        let bottom: (Double, Double, Double)
        switch sky {
        case .rain, .thunder:
            bottom = (0.118, 0.157, 0.216)
        case .snow:
            bottom = (0.180, 0.196, 0.227)
        default:
            bottom = (0.153, 0.169, 0.220)
        }
        return WeatherTint(
            top: Color(red: 0.086, green: 0.098, blue: 0.133),
            bottom: Color(red: bottom.0, green: bottom.1, blue: bottom.2),
            ink: Color(red: 0.961, green: 0.941, blue: 0.902),
            secondary: Color(red: 0.961, green: 0.941, blue: 0.902).opacity(0.62),
            chip: Color.white.opacity(0.08),
            onInk: Color(red: 0.102, green: 0.110, blue: 0.141),
            darkBackdrop: true
        )
    }

    private static func day(
        top: (Double, Double, Double),
        bottom: (Double, Double, Double),
        ink: (Double, Double, Double)
    ) -> WeatherTint {
        WeatherTint(
            top: Color(red: top.0, green: top.1, blue: top.2),
            bottom: Color(red: bottom.0, green: bottom.1, blue: bottom.2),
            ink: Color(red: ink.0, green: ink.1, blue: ink.2),
            secondary: Color(red: ink.0, green: ink.1, blue: ink.2).opacity(0.58),
            chip: Color.white.opacity(0.40),
            onInk: Color(red: 0.980, green: 0.965, blue: 0.937),
            darkBackdrop: false
        )
    }
}
