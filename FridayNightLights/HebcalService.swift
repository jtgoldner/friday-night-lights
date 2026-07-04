import Foundation

struct CandleLightingTime: Identifiable {
    let id = UUID()
    let date: Date
    let formattedTime: String
    let formattedDate: String
    let isApproximate: Bool
}

struct ShabbatSchedule {
    let upcoming: [CandleLightingTime]   // future Friday candle lightings, sorted ascending
    let mostRecentCandle: Date?          // this week's candle time if currently in/near Shabbat
    let nextHavdalah: Date?              // first havdalah at or after now
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

    /// Fetches a rolling ~12-month window of candle-lighting and havdalah times.
    /// Window starts 3 days in the past so that, when fetched during Shabbat,
    /// the current week's (already-past) candle time is available for Shabbat-mode logic.
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

        var upcoming: [CandleLightingTime] = []
        var mostRecentCandle: Date? = nil
        var nextHavdalah: Date? = nil

        for item in response.items {
            guard let date = isoFormatter.date(from: item.date) else { continue }

            if item.category == "candles" {
                // Shabbat only: keep Friday candle lightings, skip erev chag (holidays).
                let weekday = calendar.component(.weekday, from: date)
                guard weekday == 6 else { continue }

                if date > now {
                    upcoming.append(CandleLightingTime(
                        date: date,
                        formattedTime: timeFormatter.string(from: date),
                        formattedDate: dateFormatter.string(from: date),
                        isApproximate: false
                    ))
                } else {
                    // Past candle within the 3-day lookback = this week's Shabbat start.
                    if mostRecentCandle == nil || date > mostRecentCandle! {
                        mostRecentCandle = date
                    }
                }
            }

            if item.category == "havdalah" && nextHavdalah == nil && date >= now {
                nextHavdalah = date
            }
        }

        upcoming.sort { $0.date < $1.date }

        guard !upcoming.isEmpty else { throw HebcalError.noData }

        return ShabbatSchedule(
            upcoming: upcoming,
            mostRecentCandle: mostRecentCandle,
            nextHavdalah: nextHavdalah
        )
    }
}
