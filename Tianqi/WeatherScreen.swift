import SwiftUI

struct WeatherScreen: View {
    @State private var model: WeatherModel
    @State private var searching = false

    @MainActor
    init(model: WeatherModel? = nil) {
        _model = State(initialValue: model ?? WeatherModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let message = model.banner, model.report != nil {
                        banner(message)
                    }
                    if let report = model.report {
                        details(report)
                    } else {
                        status
                            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 36)
            }
            .refreshable { await model.fetch() }
            .background {
                LinearGradient(
                    colors: [tint.top, tint.bottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        searching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("搜尋地點")
                }
            }
            .tint(tint.ink)
            .preferredColorScheme(tint.darkBackdrop ? .dark : .light)
            .sheet(isPresented: $searching) {
                SearchSheet { place in
                    model.select(place)
                }
            }
            .task { await model.loadIfNeeded() }
        }
    }

    private var tint: WeatherTint {
        guard let current = model.report?.current else { return .paper }
        return .resolve(code: current.code, isDay: current.isDay)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.place.name)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint.ink)
                .lineLimit(2)
            if !model.place.detail.isEmpty {
                Text(model.place.detail)
                    .font(.system(size: 15))
                    .foregroundStyle(tint.secondary)
            }
        }
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var status: some View {
        switch model.phase {
        case .failed(let message):
            failure(message)
        case .loading, .ready:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(tint.ink)
                Text("正在取得天氣")
                    .font(.system(size: 15))
                    .foregroundStyle(tint.secondary)
            }
        }
    }

    private func details(_ report: WeatherReport) -> some View {
        let floor = (report.days.map(\.low).min() ?? 0) - 1
        let ceil = (report.days.map(\.high).max() ?? 1) + 1
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(degrees(report.current.temperature))
                    .font(.system(size: 92, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(tint.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel("氣溫 \(Int(report.current.temperature.rounded())) 度")
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: Sky.symbol(code: report.current.code, day: report.current.isDay))
                        .font(.system(size: 28))
                        .foregroundStyle(tint.ink)
                    Text(Sky.label(for: report.current.code))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(tint.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 14)
            }
            .padding(.bottom, 20)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                stat("體感", degrees(report.current.feelsLike))
                stat("濕度", "\(report.current.humidity)%")
                stat("風速", "\(Int(report.current.windKmh.rounded())) km/h")
                stat("降水", millimeters(report.current.precipitation))
            }

            Text("更新於 \(clock(report.fetchedAt, zone: report.timeZone))")
                .font(.system(size: 13))
                .foregroundStyle(tint.secondary)
                .padding(.top, 16)
                .padding(.bottom, 26)

            Text("未來 7 天")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint.ink)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(report.days.enumerated()), id: \.element.id) { index, day in
                    dayRow(day, floor: floor, ceil: ceil, zone: report.timeZone)
                    if index != report.days.count - 1 {
                        Rectangle()
                            .fill(tint.ink.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private func dayRow(_ day: ForecastDay, floor: Double, ceil: Double, zone: TimeZone) -> some View {
        let title = dayTitle(day.date, zone: zone)
        let low = degrees(day.low)
        let high = degrees(day.high)
        let rain = day.rainChance.map { "\($0)%" } ?? "–"
        return HStack(spacing: 10) {
            Text(title)
                .frame(width: 48, alignment: .leading)
            Image(systemName: Sky.symbol(code: day.code, day: true))
                .frame(width: 22)
            Text(rain)
                .font(.system(size: 13))
                .foregroundStyle(tint.secondary)
                .frame(width: 36, alignment: .trailing)
            RangeMark(
                low: day.low,
                high: day.high,
                floor: floor,
                ceil: ceil,
                ink: tint.ink.opacity(0.8),
                track: tint.ink.opacity(0.12)
            )
            Text(low)
                .foregroundStyle(tint.secondary)
                .frame(width: 36, alignment: .trailing)
            Text(high)
                .frame(width: 36, alignment: .trailing)
        }
        .font(.system(size: 16))
        .monospacedDigit()
        .foregroundStyle(tint.ink)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，最高 \(high)，最低 \(low)，降雨 \(rain)")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(tint.secondary)
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(tint.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint.chip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func banner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(tint.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("重試") {
                Task { await model.fetch() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 16)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 32))
                .foregroundStyle(tint.ink)
            Text(message)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(tint.ink)
            Button {
                Task { await model.fetch() }
            } label: {
                Text("再試一次")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(tint.ink, in: Capsule())
                    .foregroundStyle(tint.onInk)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
    }

    private func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private func millimeters(_ value: Double) -> String {
        if value < 0.05 { return "0 mm" }
        return String(format: "%.1f mm", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func clock(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dayTitle(_ date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}

private struct RangeMark: View {
    var low: Double
    var high: Double
    var floor: Double
    var ceil: Double
    var ink: Color
    var track: Color

    var body: some View {
        GeometryReader { geo in
            let span = max(ceil - floor, 0.5)
            let start = min(max((low - floor) / span, 0), 1)
            let end = min(max((high - floor) / span, 0), 1)
            let width = max(geo.size.width * (end - start), 6)
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(ink)
                    .frame(width: width)
                    .offset(x: min(geo.size.width * start, max(geo.size.width - width, 0)))
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    WeatherScreen(model: .preview)
}
