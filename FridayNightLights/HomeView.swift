import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showDebug = false
    @State private var clockTick = Date()
    @Environment(\.scenePhase) private var scenePhase

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            let _ = clockTick

            if appState.isShabbat {
                ShabbatView()
                    .environmentObject(appState)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("🕯️ Friday Night Lights")
                            .font(.custom("Georgia", size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showSettings = true }) {
                            Text(appState.zipCode)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    if appState.showTimeZoneCard {
                        TimeZoneChangeCard(onUpdateTapped: {
                            showSettings = true
                        })
                        .environmentObject(appState)
                        .padding(.top, 20)
                    }

                    Spacer()

                    if appState.isLoading {
                        ProgressView().tint(.white).scaleEffect(1.5)
                    } else if let error = appState.errorMessage {
                        ErrorCard(message: error) { appState.refreshAndSchedule() }
                    } else if let next = appState.nextCandleLighting {
                        CandleTimeCard(time: next, minutesBefore: appState.minutesBefore)
                    } else {
                        Text("Loading candle times…")
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Text("Reminders scheduled a year ahead • Times based on your ZIP code")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                        .onLongPressGesture(minimumDuration: 1.5) {
                            showDebug = true
                        }
                }
            }
        }
        .onAppear {
            appState.refreshAndSchedule()
            appState.checkForTimeZoneChange()
        }
        .onReceive(minuteTimer) { _ in
            clockTick = Date()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                clockTick = Date()
                appState.refreshAndSchedule()
                appState.checkForTimeZoneChange()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $showDebug) {
            DebugView()
        }
    }
}

struct CandleTimeCard: View {
    let time: CandleLightingTime
    let minutesBefore: Int

    var body: some View {
        VStack(spacing: 20) {
            Text(time.formattedDate)
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(2)

            Text(time.formattedTime)
                .font(.custom("Georgia", size: 64))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Candle Lighting")
                .font(.title3)
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.1))
                .fontWeight(.medium)

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 60)

            Text("You'll be notified \(minutesBefore) minutes before, every Friday. Shabbat Shalom!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if time.isApproximate {
                Text("Approximate — exact time updates Sunday.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(36)
        .background(Color.white.opacity(0.08))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("⚠️").font(.largeTitle)
            Text(message)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .font(.subheadline)
            Button("Try Again", action: retry)
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.1))
                .fontWeight(.semibold)
        }
        .padding(32)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .padding(.horizontal, 32)
    }
}
