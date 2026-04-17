import SwiftUI

struct DailyWelcomeView: View {
    @Binding var isPresented: Bool
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.18),
                    Color(red: 0.12, green: 0.16, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text(Self.greetingLine(for: Date()))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Welcome back to Respite.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    onContinue()
                    isPresented = false
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
        .interactiveDismissDisabled(true)
    }

    static func greetingLine(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12:
            return "Good morning"
        case 12 ..< 17:
            return "Good afternoon"
        case 17 ..< 22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
}
