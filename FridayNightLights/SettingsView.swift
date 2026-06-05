import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var zipInput: String = ""
    @State private var minutesInput: String = ""
    @State private var showMinutesError = false
    @FocusState private var focused: Bool

    private var formValid: Bool {
        guard zipInput.count == 5 else { return false }
        guard let mins = Int(minutesInput), mins >= 1, mins <= 99 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundBottom").ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Update your location or notification timing.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ZIP CODE")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.leading, 4)

                        TextField("ZIP Code", text: $zipInput)
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: zipInput) { newValue in
                                zipInput = String(newValue.filter { $0.isNumber }.prefix(5))
                            }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALERT ME THIS MANY MINUTES BEFORE")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                            .padding(.leading, 4)

                        TextField("Minutes (1–99)", text: $minutesInput)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showMinutesError ? Color.red.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 1)
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
                    .padding(.horizontal)

                    Button(action: save) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(formValid ? Color("AccentGold") : Color.white.opacity(0.2))
                            .foregroundColor(formValid ? .black : .white.opacity(0.4))
                            .cornerRadius(12)
                            .fontWeight(.semibold)
                    }
                    .disabled(!formValid)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            zipInput = appState.zipCode
            minutesInput = "\(appState.minutesBefore)"
            focused = true
        }
    }

    private func save() {
        guard zipInput.count == 5 else { return }
        guard let mins = Int(minutesInput), mins >= 1, mins <= 99 else {
            showMinutesError = true
            return
        }
        appState.minutesBefore = mins
        appState.zipCode = zipInput
        appState.refreshAndSchedule()
        dismiss()
    }
}
