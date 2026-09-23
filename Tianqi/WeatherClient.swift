import Foundation

struct WeatherClient: Sendable {
    private let session: URLSession

    init(session: URLSession = WeatherClient.shared) {
        self.session = session
    }

    func search(_ query: String) async throws -> [Place] {
        let text = rewrite(query)
        guard !text.isEmpty else { return [] }
        let data = try await send(try searchURL(text))
        let envelope = try decode(GeoEnvelope.self, from: data)
        return pick(envelope.results ?? [])
    }

    func report(for place: Place) async throws -> WeatherReport {
        let data = try await send(try forecastURL(place))
        let envelope = try decode(ForecastEnvelope.self, from: data)
        return try makeReport(place: place, envelope: envelope)
    }

    private static let shared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 18
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private let aliases: [String: String] = [
        "台北": "Taipei",
        "臺北": "Taipei",
        "台北市": "Taipei",
        "臺北市": "Taipei",
        "台中": "Taichung",
        "臺中": "Taichung",
        "台南": "Tainan",
        "臺南": "Tainan",
        "高雄": "Kaohsiung",
        "高雄市": "Kaohsiung",
        "倫敦": "London",
        "伦敦": "London",
        "首爾": "Seoul",
        "首尔": "Seoul",
        "廣州": "广州",
    ]

    private func rewrite(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return aliases[text] ?? text
    }

    private func searchURL(_ query: String) throws -> URL {
        guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
            throw WeatherError.badURL
        }
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "12"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { throw WeatherError.badURL }
        return url
    }

    private func forecastURL(_ place: Place) throws -> URL {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw WeatherError.badURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: number(place.latitude)),
            URLQueryItem(name: "longitude", value: number(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
        ]
        guard let url = components.url else { throw WeatherError.badURL }
        return url
    }

    private func send(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw WeatherError.undecodable
            }
            guard (200..<300).contains(http.statusCode) else {
                throw WeatherError.status(http.statusCode)
            }
            return data
        } catch let error as WeatherError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw WeatherError.network(error.code)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WeatherError.network(.unknown)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw WeatherError.undecodable
        }
    }

    private func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func pick(_ items: [GeoItem]) -> [Place] {
        let allowed: Set<String> = [
            "PPLC", "PPLA", "PPLA2", "PPLA3", "PPLA4", "PPL", "PPLG", "PPLS", "PPLX", "PPLL",
            "PCLI", "PCLD", "PCLS", "ADM1", "ADM2", "ADM3",
        ]
        var pool = items.filter { item in
            guard let code = item.feature_code else { return true }
            return allowed.contains(code)
        }
        if pool.isEmpty { pool = items }

        pool.sort { a, b in
            let left = a.population ?? -1
            let right = b.population ?? -1
            if left != right { return left > right }
            return featureRank(a.feature_code) < featureRank(b.feature_code)
        }

        var chosen: [GeoItem] = []
        for item in pool {
            let duplicated = chosen.contains { existing in
                existing.id == item.id
                    || (existing.name == item.name
                        && abs(existing.latitude - item.latitude) < 0.25
                        && abs(existing.longitude - item.longitude) < 0.25)
            }
            if duplicated { continue }
            chosen.append(item)
            if chosen.count == 8 { break }
        }
        return chosen.map(mapPlace)
    }

    private func featureRank(_ code: String?) -> Int {
        switch code {
        case "PPLC": return 0
        case "PPLA": return 1
        case "PPLA2": return 2
        case "PPLA3": return 3
        case "PPLA4": return 4
        case "PPL": return 5
        case "PPLG", "PPLS", "PPLX", "PPLL": return 6
        default: return 8
        }
    }

    private func mapPlace(_ item: GeoItem) -> Place {
        Place(
            id: item.id,
            name: item.name,
            admin: cleanedAdmin(item),
            country: item.country ?? "",
            latitude: item.latitude,
            longitude: item.longitude
        )
    }

    private func cleanedAdmin(_ item: GeoItem) -> String {
        let primary = item.admin1?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secondary = item.admin2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if primary.isEmpty || primary.contains(" or ") {
            return secondary
        }
        return primary
    }

    private func makeReport(place: Place, envelope: ForecastEnvelope) throws -> WeatherReport {
        let zone = TimeZone(identifier: envelope.timezone) ?? .current
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = zone
        parser.dateFormat = "yyyy-MM-dd"

        let daily = envelope.daily
        let count = daily.time.count
        guard count > 0,
              daily.weather_code.count == count,
              daily.temperature_2m_max.count == count,
              daily.temperature_2m_min.count == count,
              daily.precipitation_probability_max.count == count
        else { throw WeatherError.undecodable }

        var days: [ForecastDay] = []
        days.reserveCapacity(count)
        for index in 0..<count {
            guard let date = parser.date(from: daily.time[index]) else { continue }
            let chance = daily.precipitation_probability_max[index].map { Int($0.rounded()) }
            days.append(
                ForecastDay(
                    date: date,
                    code: daily.weather_code[index],
                    high: daily.temperature_2m_max[index],
                    low: daily.temperature_2m_min[index],
                    rainChance: chance
                )
            )
        }
        if days.isEmpty { throw WeatherError.undecodable }

        let current = envelope.current
        return WeatherReport(
            place: place,
            current: CurrentConditions(
                temperature: current.temperature_2m,
                feelsLike: current.apparent_temperature,
                humidity: Int(current.relative_humidity_2m.rounded()),
                windKmh: current.wind_speed_10m,
                precipitation: current.precipitation,
                code: current.weather_code,
                isDay: current.is_day == 1
            ),
            days: days,
            timeZone: zone,
            fetchedAt: Date()
        )
    }
}

private struct GeoEnvelope: Decodable {
    let results: [GeoItem]?
}

private struct GeoItem: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    let admin2: String?
    let feature_code: String?
    let population: Double?
}

private struct ForecastEnvelope: Decodable {
    let timezone: String
    let current: CurrentBody
    let daily: DailyBody
}

private struct CurrentBody: Decodable {
    let temperature_2m: Double
    let relative_humidity_2m: Double
    let apparent_temperature: Double
    let weather_code: Int
    let wind_speed_10m: Double
    let precipitation: Double
    let is_day: Int
}

private struct DailyBody: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Double?]
}
