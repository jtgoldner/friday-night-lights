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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    init() {
        self.zipCode = defaults.string(forKey: "zipCode") ?? ""
        let saved = defaults.integer(forKey: "minutesBefore")
        self.minutesBefore = saved > 0 ? saved : 18
    }

    func refreshAndSchedule() {
        guard !zipCode.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let times = try await HebcalService.fetchUpcomingCandleTimes(zip: zipCode, weeks: 8)
                await MainActor.run {
                    self.nextCandleLighting = times.first
                    self.isLoading = false
                }
                await NotificationScheduler.scheduleNotifications(for: times, minutesBefore: minutesBefore)
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
        NotificationScheduler.cancelAll()
    }
}
