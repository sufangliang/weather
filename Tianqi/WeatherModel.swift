import Foundation
import Observation

@MainActor
@Observable
final class WeatherModel {
    var place: Place
    var report: WeatherReport?
    var phase: Phase
    var banner: String?

    private let client: WeatherClient
    private var ticket = 0

    enum Phase {
        case loading
        case ready
        case failed(String)
    }

    init(seed: WeatherReport? = nil, client: WeatherClient = WeatherClient()) {
        self.client = client
        if let seed {
            place = seed.place
            report = seed
            phase = .ready
            return
        }
        place = Self.storedPlace() ?? .taipei
        phase = .loading
    }

    func loadIfNeeded() async {
        guard report == nil else { return }
        await fetch()
    }

    func select(_ next: Place) {
        let keep = report != nil && near(place, next)
        place = next
        Self.store(next)
        banner = nil
        if !keep {
            report = nil
            phase = .loading
        }
        Task { await fetch() }
    }

    func fetch() async {
        ticket += 1
        let current = ticket
        let target = place
        if report == nil {
            phase = .loading
        }
        do {
            let next = try await client.report(for: target)
            guard current == ticket else { return }
            report = next
            phase = .ready
            banner = nil
            Self.store(target)
        } catch is CancellationError {
            return
        } catch {
            guard current == ticket else { return }
            let text = (error as? WeatherError)?.message ?? "出了點問題"
            if report == nil {
                phase = .failed(text)
                banner = nil
            } else {
                banner = text
            }
        }
    }

    private func near(_ lhs: Place, _ rhs: Place) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.05 && abs(lhs.longitude - rhs.longitude) < 0.05
    }

    private static let storeKey = "tianqi.lastPlace"

    private static func storedPlace() -> Place? {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    private static func store(_ place: Place) {
        guard let data = try? JSONEncoder().encode(place) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    static var preview: WeatherModel {
        WeatherModel(seed: .sample)
    }
}
