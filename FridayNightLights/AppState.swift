import Foundation

class AppState: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var zipCode: String {
        didSet { defaults.set(zipCode, forKey: "zipCode") }
    }
    @Published var minutesBefore: Int {
        didSet { defaults.set(minutesBefore, forKey: "minutesBefore") }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var nextCandleLighting: CandleLightingTime? = nil
    @Published var havdalahTime: Date? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Time-zone-change travel prompt
    @Published var showTimeZoneCard: Bool = false

    private var lastCandleDate: Date? {
        get { defaults.object(forKey: "lastCandleDate") as? Date }
        set { defaults.set(newValue, forKey: "lastCandleDate") }
    }

    private var currentShabbatEnd: Date? {
        get { defaults.object(forKey: "currentShabbatEnd") as? Date }
        set { defaults.set(newValue, forKey: "currentShabbatEnd") }
    }

    private var lastKnownTimeZoneID: String? {
        get { defaults.string(forKey: "lastKnownTimeZoneID") }
        set { defaults.set(newValue, forKey: "lastKnownTimeZoneID") }
    }

    init() {
        self.zipCode = defaults.string(forKey: "zipCode") ?? ""
        let saved = defaults.integer(forKey: "minutesBefore")
        self.minutesBefore = saved > 0 ? saved : 18
        self.havdalahTime = defaults.object(forKey: "lastHavdalahDate") as? Date
        // Default ON for new and existing users (key absent = true)
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
    }

    var isShabbat: Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        guard weekday == 6 || weekday == 7 else { return false }
        guard let start = lastCandleDate ?? nextCandleLighting?.date else { return false }
        guard now >= start else { return false }

        if let end = currentShabbatEnd {
            return now < end
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
                    minutesBefore: minutesBefore,
                    soundEnabled: soundEnabled
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "Couldn't load candle-lighting times. Check your zip code and try again."
                    self.isLoading = false
                }
            }
        }
    }

    /// Compares the device's current time zone against the last known one.
    /// Shows a soft, dismissible prompt on change. Call on app foreground.
    func checkForTimeZoneChange() {
        guard !zipCode.isEmpty else { return }  // no point prompting before onboarding is done

        let current = TimeZone.current.identifier

        guard let last = lastKnownTimeZoneID else {
            // First launch ever recording a time zone — just record it, don't prompt.
            lastKnownTimeZoneID = current
            return
        }

        if current != last {
            showTimeZoneCard = true
        }
        // Note: lastKnownTimeZoneID is intentionally NOT updated here.
        // It only updates when the user acts on the card (dismiss, keep, or update),
        // so the card doesn't silently stop reappearing on every subsequent launch
        // in the new time zone before the user has responded.
    }

    func acknowledgeTimeZoneChange() {
        lastKnownTimeZoneID = TimeZone.current.identifier
        showTimeZoneCard = false
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
