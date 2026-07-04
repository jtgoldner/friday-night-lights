import SwiftUI
import UserNotifications

struct DebugView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pending: [(id: String, fireDate: Date?)] = []

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d 'at' h:mm a"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundBottom").ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("\(pending.count) notification\(pending.count == 1 ? "" : "s") scheduled")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.1))
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    if pending.isEmpty {
                        Spacer()
                        Text("⚠️ No pending notifications.\nOpen the app with a valid ZIP to schedule.")
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(pending, id: \.id) { item in
                                    HStack {
                                        Text(item.id.hasSuffix("rearm") ? "🔄" : "🕯️")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.fireDate.map { formatter.string(from: $0) } ?? "Unknown fire date")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Text(item.id)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Scheduled Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let items = requests.map { req -> (String, Date?) in
                let trigger = req.trigger as? UNCalendarNotificationTrigger
                return (req.identifier, trigger?.nextTriggerDate())
            }
            .sorted { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }

            DispatchQueue.main.async {
                self.pending = items.map { (id: $0.0, fireDate: $0.1) }
            }
        }
    }
}
