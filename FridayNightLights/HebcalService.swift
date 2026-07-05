import Foundation

struct CandleLightingTime: Identifiable {
    let id = UUID()
    let date: Date
    let formattedTime: String
    let formattedDate: String
    let isApproximate: Bool
}

struct ShabbatSchedule {
    let upcoming: [CandleLightingTime]   // future Friday candle lightings, ascending
    let mostRecentCandle: Date?          // this week's candle time if within lookback
    let nextHavdalah: Date?              // first havdalah at or after now (for display)
    let currentShabbatEnd: Date?         // havdalah that ends the Shabbat of mostRecentCandle
}

enum HebcalError: Error {
    case invalidURL
    case noData
    case decodingError
}

private struct HebcalResponse: Codable {
    let items: [HebcalItem]
}

private struct HebcalItem: Codable {
    let title: String
    let date: String
    let category: String
}

struct HebcalService {

    static func fetchSchedule(zip: String) async throws -> ShabbatSchedule {
        let calendar = Calendar.current
        let now = Date()

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")

        let startDate = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let endDate = calendar.date(byAdding: .day, value: 364, to: now) ?? now
        let start = dayFormatter.string(from: startDate)
        let end = dayFormatter.string(from: endDate)

        guard let url = URL(string: "https://www.hebcal.com/hebcal?v=1&cfg=json&c=on&b=18&m=50&maj=off&min=off&mod=off&nx=off&mf=off&ss=off&s=off&leyning=off&zip=\(zip)&start=\(start)&end=\(end)") else {
            throw HebcalError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HebcalResponse.self, from: data)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"

        // Collect all candle + havdalah events with parsed dates, in order.
        var candleDates: [Date] = []
        var havdalahDates: [Date] = []
        var upcoming: [CandleLightingTime] = []

        for item in response.items {
            guard let date = isoFormatter.date(from: item.date) else { continue }

            if item.category == "candles" {
                let weekday = calendar.component(.weekday, from: date)
                guard weekday == 6 else { continue }   // Fridays only (skip erev chag)
                candleDates.append(date)
                if date > now {
                    upcoming.append(CandleLightingTime(
                        date: date,
                        formattedTime: timeFormatter.string(from: date),
                        formattedDate: dateFormatter.string(from: date),
                        isApproximate: false
                    ))
                }
            } else if item.category == "havdalah" {
                havdalahDates.append(date)
            }
        }

        candleDates.sort()
        havdalahDates.sort()
        upcoming.sort { $0.date < $1.date }

        // Most recent candle at/just before now (within the 3-day lookback window).
        let mostRecentCandle = candleDates.filter { $0 <= now }.last

        // The havdalah that ENDS that Shabbat = first havdalah strictly after that candle.
        var currentShabbatEnd: Date? = nil
        if let candle = mostRecentCandle {
            currentShabbatEnd = havdalahDates.first { $0 > candle }
        }

        // Next upcoming havdalah, for display purposes.
        let nextHavdalah = havdalahDates.first { $0 >= now }

        guard !upcoming.isEmpty else { throw HebcalError.noData }

        return ShabbatSchedule(
            upcoming: upcoming,
            mostRecentCandle: mostRecentCandle,
            nextHavdalah: nextHavdalah,
            currentShabbatEnd: currentShabbatEnd
        )
    }
}
