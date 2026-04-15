import Foundation
import UserNotifications

struct NotificationScheduler {

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleNotifications(for times: [CandleLightingTime], minutesBefore: Int) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix("shabbat-") }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for time in times {
            let notifyDate = time.date.addingTimeInterval(TimeInterval(-minutesBefore * 60))
            guard notifyDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Shabbat Shalom"
            content.body = minutesBefore == 0
                ? "Candle lighting is now — \(time.formattedTime). Shabbat Shalom!"
                : "Candle lighting in \(minutesBefore) min — \(time.formattedTime). Shabbat Shalom!"
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: notifyDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "shabbat-\(time.date.timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
