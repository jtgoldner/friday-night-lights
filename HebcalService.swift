import Foundation

struct CandleLightingTime: Identifiable {
    let id = UUID()
    let date: Date
    let formattedTime: String
    let formattedDate: String
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
    static func fetchUpcomingCandleTimes(zip: String, weeks: Int = 8) async throws -> [CandleLightingTime] {
        var results: [CandleLightingTime] = []

        guard let url = URL(string: "https://www.hebcal.com/shabbat?cfg=json&zip=\(zip)&m=18&weeks=\(weeks)") else {
            throw HebcalError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HebcalResponse.self, from: data)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"

        for item in response.items where item.category == "candles" {
            guard let date = isoFormatter.date(from: item.date) else { continue }
            guard date > Date() else { continue }

            results.append(CandleLightingTime(
                date: date,
                formattedTime: timeFormatter.string(from: date),
                formattedDate: dateFormatter.string(from: date)
            ))
        }

        if results.isEmpty { throw HebcalError.noData }
        return results.sorted { $0.date < $1.date }
    }
}
