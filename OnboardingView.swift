import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var zipInput: String = ""
    @State private var minutesInput: String = "18"
    @State private var isSubmitting = false
    @State private var showZipError = false
    @State private var showMinutesError = false
    @FocusState private var focusedField: Field?

    enum Field { case zip, minutes }

    private var formValid: Bool {
        guard zipInput.count == 5 else { return false }
        guard let mins = Int(minutesInput), mins >= 1, mins <= 99 else { return false }
        return true
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("🕯️")
                    .font(.system(size: 72))
                    .padding(.bottom, 24)

                Text("Friday Night Lights")
                    .font(.custom("Georgia", size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Weekly candle-lighting reminders, timed to your location.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 16) {
                    // ZIP field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ZIP CODE")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.leading, 4)

                        TextField("Enter your ZIP code", text: $zipInput)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                            .focused($focusedField, equals: .zip)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .tint(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showZipError ? Color.red.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: zipInput) { newValue in
                                zipInput = String(newValue.filter { $0.isNumber }.prefix(5))
                                showZipError = false
                            }

                        if showZipError {
                            Text("Please enter a valid 5-digit ZIP code.")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.leading, 4)
                        }
                    }

                    // Minutes field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALERT ME THIS MANY MINUTES BEFORE")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.leading, 4)

                        TextField("Minutes (1–99)", text: $minutesInput)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .minutes)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .tint(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showMinutesError ? Color.red.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: minutesInput) { newValue in
                                minutesInput = String(newValue.filter { $0.isNumber }.prefix(2))
                                showMinutesError = false
                            }

                        if showMinutesError {
                            Text("Please enter a whole number between 1 and 99.")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.leading, 4)
                        }
                    }

                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white).padding(.trailing, 4)
                            }
                            Text(isSubmitting ? "Setting up…" : "Get Reminders")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(formValid ? Color.white : Color.white.opacity(0.3))
                        .foregroundColor(formValid ? Color("AccentGold") : .white.opacity(0.5))
                        .cornerRadius(12)
                        .font(.headline)
                    }
                    .disabled(!formValid || isSubmitting)
                    .animation(.easeInOut(duration: 0.2), value: formValid)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { focusedField = .zip }
    }

    private func submit() {
        guard zipInput.count == 5 else { showZipError = true; return }
        guard let mins = Int(minutesInput), mins >= 1, mins <= 99 else { showMinutesError = true; return }

        showZipError = false
        showMinutesError = false
        isSubmitting = true
        focusedField = nil

        Task {
            let _ = await NotificationScheduler.requestPermission()
            await MainActor.run {
                appState.minutesBefore = mins
                appState.zipCode = zipInput
                appState.refreshAndSchedule()
            }
        }
    }
}
