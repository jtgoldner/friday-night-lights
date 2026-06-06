import Foundation

class AppState: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var zipCode: String {
        didSet { defaults.set(zipCode, forKey: "zipCode") }
    }
    @Published var minutesBefore: Int {
        didSet { defaults.set(minutesBefore, forKey: "minutesBefore") }
    }
    @Published var nextCandleLighting: CandleLightingTime? = nil
    @Published var havdalahTime: Date? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var lastCandleDate: Date? {
        get { defaults.object(forKey: "lastCandleDate") as? Date }
        set { defaults.set(newValue, forKey: "lastCandleDate") }
    }

    private var lastHavdalahDate: Date? {
        get { defaults.object(forKey: "lastHavdalahDate") as? Date }
        set { defaults.set(newValue, forKey: "lastHavdalahDate") }
    }

    init() {
        self.zipCode = defaults.string(forKey: "zipCode") ?? ""
        let saved = defaults.integer(forKey: "minutesBefore")
        self.minutesBefore = saved > 0 ? saved : 18
        self.havdalahTime = defaults.object(forKey: "lastHavdalahDate") as? Date
    }

    var isShabbat: Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        if weekday == 6 {
            if let candle = lastCandleDate ?? nextCandleLighting?.date {
                return now >= candle
            }
            return false
        } else if weekday == 7 {
            if let havdalah = lastHavdalahDate ?? havdalahTime {
                return now < havdalah
            }
            return true
        }
        return false
    }

    var havdalahFormattedTime: String? {
        guard let h = lastHavdalahDate ?? havdalahTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: h)
    }

    var candleLightingFormattedTime: String? {
        guard let c = lastCandleDate ?? nextCandleLighting?.date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: c)
    }

    func refreshAndSchedule() {
        guard !zipCode.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await HebcalService.fetchCandleAndHavdalah(zip: zipCode)
                await MainActor.run {
                    self.nextCandleLighting = result.candle
                    self.havdalahTime = result.havdalah
                    self.lastCandleDate = result.candle.date
                    self.lastHavdalahDate = result.havdalah
                    self.isLoading = false
                }
                await NotificationScheduler.scheduleNotifications(
                    for: [result.candle],
                    minutesBefore: minutesBefore
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "Couldn't load candle-lighting times. Check your zip code and try again."
                    self.isLoading = false
                }
            }
        }
    }

    func resetZipCode() {
        zipCode = ""
        nextCandleLighting = nil
        havdalahTime = nil
        lastCandleDate = nil
        lastHavdalahDate = nil
        NotificationScheduler.cancelAll()
    }
}
