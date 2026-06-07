import Foundation

struct CandleLightingTime: Identifiable {
    let id = UUID()
    let date: Date
    let formattedTime: String
    let formattedDate: String
    let isApproximate: Bool
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

    static func fetchCandleAndHavdalah(zip: String) async throws -> (candle: CandleLightingTime, havdalah: Date?) {
        guard let url = URL(string: "https://www.hebcal.com/shabbat?cfg=json&zip=\(zip)&m=50&ue=on&b=18&M=on&s=on") else {
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

        var rawCandleDate: Date? = nil
        var havdalahDate: Date? = nil

        for item in response.items {
            guard let date = isoFormatter.date(from: item.date) else { continue }

            if item.category == "candles" && rawCandleDate == nil {
                rawCandleDate = date
            }

            if item.category == "havdalah" && havdalahDate == nil {
                havdalahDate = date
            }
        }

        guard let candleDate = rawCandleDate else { throw HebcalError.noData }

        // If candle time is in the past (e.g. Saturday night after havdalah),
        // approximate next week by adding 7 days.
        let isApproximate = candleDate <= Date()
        let displayDate = isApproximate ? candleDate.addingTimeInterval(7 * 24 * 60 * 60) : candleDate

        let candle = CandleLightingTime(
            date: displayDate,
            formattedTime: timeFormatter.string(from: displayDate),
            formattedDate: dateFormatter.string(from: displayDate),
            isApproximate: isApproximate
        )

        return (candle: candle, havdalah: havdalahDate)
    }
}
