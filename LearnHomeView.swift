import SwiftUI

struct LearnHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Preserving Mithila")
                    .font(.custom("Georgia", size: 34).bold())
                    .padding(.horizontal)
                
                // Card 1: History
                NavigationLink(destination: Text("History Detail Content")) {
                    LearnCard(title: "The Story of Mithila",
                              subtitle: "A 2,500 year old heritage.",
                              icon: "clock.fill")
                }
                
                // Card 2: Composition
                NavigationLink(destination: Text("Rules Detail Content")) {
                    LearnCard(title: "Sacred Rules",
                              subtitle: "Borders, double lines, and empty space.",
                              icon: "rule.fill")
                }
                
                // Card 3: Symbolism
                NavigationLink(destination: Text("Symbolism Detail Content")) {
                    LearnCard(title: "Themes & Symbols",
                              subtitle: "What the Fish and Sun represent.",
                              icon: "leaf.fill")
                }
            }
            .padding()
        }
        .background(Color.handmadePaper.opacity(0.5))
    }
}

// A reusable component for the Learn Tab cards
struct LearnCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                // Using .uiPrimaryText (Color.primary) ensures visibility
                Text(title)
                    .font(.headline)
                    .foregroundColor(.uiPrimaryText)
                
                // Using .uiSecondaryText (Color.secondary) for the grey feel
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.uiSecondaryText)
            }
            Spacer()
            Image(systemName: icon)
                .foregroundColor(.deepVermillion)
                .font(.title2)
        }
        .padding()
        // Card background adapts to Dark/Light mode automatically
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}
