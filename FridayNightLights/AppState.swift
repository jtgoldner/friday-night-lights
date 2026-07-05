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

    // The havdalah that ENDS the Shabbat tied to lastCandleDate.
    // Distinct from havdalahTime (next upcoming), which is used only for display.
    private var currentShabbatEnd: Date? {
        get { defaults.object(forKey: "currentShabbatEnd") as? Date }
        set { defaults.set(newValue, forKey: "currentShabbatEnd") }
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

        // Only Friday or Saturday can be Shabbat.
        guard weekday == 6 || weekday == 7 else { return false }

        // Shabbat has a hard start (candle lighting) and hard end (havdalah).
        // We're in Shabbat only if now is between this week's candle and its havdalah.
        guard let start = lastCandleDate ?? nextCandleLighting?.date else { return false }

        // If we haven't reached candle lighting yet (early Friday), not Shabbat.
        guard now >= start else { return false }

        // If we know when this Shabbat ends, respect it precisely.
        if let end = currentShabbatEnd {
            return now < end
        }

        // Fallback if havdalah unknown: treat Shabbat as ended once it's Saturday
        // night past a conservative hour, otherwise still Shabbat.
        if weekday == 7 {
            // Without a known end time, assume Shabbat runs until end of Saturday.
            return true
        }
        return true
    }

    var havdalahFormattedTime: String? {
        guard let h = havdalahTime else { return nil }
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
                let result = try await HebcalService.fetchSchedule(zip: zipCode)
                await MainActor.run {
                    self.nextCandleLighting = result.upcoming.first
                    self.havdalahTime = result.nextHavdalah
                    self.lastCandleDate = result.mostRecentCandle ?? result.upcoming.first?.date
                    self.currentShabbatEnd = result.currentShabbatEnd
                    self.isLoading = false
                }
                await NotificationScheduler.scheduleNotifications(
                    for: result.upcoming,
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
        currentShabbatEnd = nil
        NotificationScheduler.cancelAll()
    }
}
