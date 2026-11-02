import Foundation
import UserNotifications

struct NotificationScheduler {
    /// iOS allows max 64 pending local notifications per app.
    /// 52 weekly reminders + 1 re-arm keeps us safely under the cap.
    private static let maxScheduled = 52

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        } catch {
            return false
        }
    }

    static func scheduleNotifications(for times: [CandleLightingTime], minutesBefore: Int, soundEnabled: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix("shabbat-") }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let toSchedule = times
            .filter { $0.date.addingTimeInterval(TimeInterval(-minutesBefore * 60)) > Date() }
            .prefix(maxScheduled)

        for time in toSchedule {
            let notifyDate = time.date.addingTimeInterval(TimeInterval(-minutesBefore * 60))

            let content = UNMutableNotificationContent()
            content.title = "Shabbat Shalom"
            content.body = minutesBefore == 0
                ? "Candle lighting is now — \(time.formattedTime). Shabbat Shalom!"
                : "Candle lighting in \(minutesBefore) min — \(time.formattedTime). Shabbat Shalom!"
            // Sound off = banner only. iOS ties haptics to the notification sound,
            // so no sound also means no vibration.
            content.sound = soundEnabled
                ? UNNotificationSound(named: UNNotificationSoundName("shabbat_shalom_tone.aiff"))
                : nil
            content.interruptionLevel = .timeSensitive

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

        // Re-arm safety net: if the user never opens the app again, the final
        // scheduled reminder is followed by a prompt to reopen and refresh.
        if let last = toSchedule.last {
            let rearmDate = last.date.addingTimeInterval(5 * 24 * 60 * 60)
            let content = UNMutableNotificationContent()
            content.title = "Keep your reminders coming"
            content.body = "Open Friday Night Lights to schedule your next year of candle-lighting reminders. 🕯️"
            content.sound = soundEnabled ? .default : nil

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: rearmDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "shabbat-rearm",
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
