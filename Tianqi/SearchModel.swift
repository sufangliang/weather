import Foundation
import Observation

@MainActor
@Observable
final class SearchModel {
    var query = ""
    var results: [Place] = []
    var phase: Phase = .idle

    private let client: WeatherClient
    private var task: Task<Void, Never>?
    private var ticket = 0

    enum Phase {
        case idle
        case loading
        case done
        case failed(String)
    }

    var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(client: WeatherClient = WeatherClient()) {
        self.client = client
    }

    func schedule() {
        task?.cancel()
        ticket += 1
        let current = ticket
        let text = trimmed
        guard !text.isEmpty else {
            results = []
            phase = .idle
            return
        }
        phase = .loading
        results = []
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 280_000_000)
            } catch {
                return
            }
            guard current == ticket else { return }
            await perform(text, ticket: current)
        }
    }

    func submit() {
        let text = trimmed
        guard !text.isEmpty else { return }
        task?.cancel()
        ticket += 1
        let current = ticket
        phase = .loading
        task = Task { await perform(text, ticket: current) }
    }

    private func perform(_ text: String, ticket current: Int) async {
        do {
            let found = try await client.search(text)
            guard current == ticket else { return }
            results = found
            phase = .done
        } catch is CancellationError {
            return
        } catch {
            guard current == ticket else { return }
            phase = .failed((error as? WeatherError)?.message ?? "搜尋失敗")
        }
    }
}
