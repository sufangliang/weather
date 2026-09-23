import Foundation

struct Place: Identifiable, Hashable, Codable, Sendable {
    var id: Int
    var name: String
    var admin: String
    var country: String
    var latitude: Double
    var longitude: Double

    var detail: String {
        var parts: [String] = []
        if !admin.isEmpty, admin != name, !name.contains(admin), !admin.contains(name) {
            parts.append(admin)
        }
        if !country.isEmpty, country != name, country != admin {
            parts.append(country)
        }
        return parts.joined(separator: " · ")
    }

    static let shortcuts: [Place] = [
        Place(id: -1, name: "台北", admin: "", country: "台灣", latitude: 25.05306, longitude: 121.52639),
        Place(id: -2, name: "香港", admin: "", country: "", latitude: 22.27832, longitude: 114.17469),
        Place(id: -3, name: "東京", admin: "東京都", country: "日本", latitude: 35.6895, longitude: 139.69171),
        Place(id: -4, name: "上海", admin: "", country: "中國", latitude: 31.22222, longitude: 121.45806),
        Place(id: -5, name: "新加坡", admin: "", country: "", latitude: 1.35208, longitude: 103.81984),
        Place(id: -6, name: "倫敦", admin: "", country: "英國", latitude: 51.50722, longitude: -0.1275),
    ]

    static var taipei: Place { shortcuts[0] }
}

struct CurrentConditions: Equatable, Sendable {
    var temperature: Double
    var feelsLike: Double
    var humidity: Int
    var windKmh: Double
    var precipitation: Double
    var code: Int
    var isDay: Bool
}

struct ForecastDay: Identifiable, Equatable, Sendable {
    var date: Date
    var code: Int
    var high: Double
    var low: Double
    var rainChance: Int?

    var id: Date { date }
}

struct WeatherReport: Equatable, Sendable {
    var place: Place
    var current: CurrentConditions
    var days: [ForecastDay]
    var timeZone: TimeZone
    var fetchedAt: Date

    static var sample: WeatherReport {
        var calendar = Calendar(identifier: .gregorian)
        let zone = TimeZone(identifier: "Asia/Taipei") ?? .current
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: Date())
        let codes = [1, 2, 61, 3, 0, 45, 2]
        let highs = [31.0, 32, 28, 29, 31, 27, 30]
        let lows = [24.0, 25, 23, 23, 24, 22, 24]
        let rain = [10, 20, 70, 30, 5, 15, 10]
        let days: [ForecastDay] = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return ForecastDay(
                date: date,
                code: codes[offset],
                high: highs[offset],
                low: lows[offset],
                rainChance: rain[offset]
            )
        }
        return WeatherReport(
            place: .taipei,
            current: CurrentConditions(
                temperature: 30,
                feelsLike: 33,
                humidity: 49,
                windKmh: 14,
                precipitation: 0,
                code: 1,
                isDay: true
            ),
            days: days,
            timeZone: zone,
            fetchedAt: Date()
        )
    }
}
