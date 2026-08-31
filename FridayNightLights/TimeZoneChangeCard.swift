import SwiftUI

struct TimeZoneChangeCard: View {
    @EnvironmentObject var appState: AppState
    let onUpdateTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("✈️")
                    .font(.title2)
                Spacer()
                Button(action: { appState.acknowledgeTimeZoneChange() }) {
                    Text("✕")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.subheadline)
                }
            }

            Text("Looks like you've traveled")
                .font(.headline)
                .foregroundColor(.white)

            Text("Your ZIP code is still set to \(appState.zipCode). Want to update it so candle lighting reflects where you are now?")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: {
                    appState.acknowledgeTimeZoneChange()
                    onUpdateTapped()
                }) {
                    Text("Update My ZIP Code")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.8, green: 0.6, blue: 0.1))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }

                Button(action: { appState.acknowledgeTimeZoneChange() }) {
                    Text("Keep \(appState.zipCode) — I'm not lighting here")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.75))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.07))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}
