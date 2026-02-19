import SwiftUI

struct OnboardingView: View {
    @Binding var hasFinishedOnboarding: Bool
    
    var body: some View {
        ZStack {
            // Locked to the static handmadePaper color (Cream)
            Color.handmadePaper.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Mithila")
                        .font(.custom("Georgia", size: 60).bold())
                        // Force dark text even in Dark Mode
                        .foregroundColor(.lampBlack)
                    
                    Text("The Art of Bihar")
                        .font(.title2.italic())
                        // Using your brand red which works on cream
                        .foregroundColor(.deepVermillion)
                }
                
                Text("For over 2,500 years, women in Mithila have painted these walls to celebrate life, nature, and divinity. Now, it's your turn to preserve this heritage.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .font(.body)
                    // Ensure this text is also visible
                    .foregroundColor(.lampBlack)
                
                Spacer()
                
                Button(action: {
                    withAnimation { hasFinishedOnboarding = true }
                }) {
                    Text("Start Painting")
                        .font(.headline)
                        .foregroundColor(.white) // Button text stays white
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        // Button background stays dark
                        .background(Color.lampBlack)
                        .cornerRadius(30)
                }
                .padding(.bottom, 50)
            }
        }
        // This modifier tells the Onboarding screen to ignore the iPad's Dark Mode
        // and always display in the Light style for visual consistency.
        .preferredColorScheme(.light)
    }
}
