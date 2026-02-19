import SwiftUI

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
            )
            .onTapGesture(perform: action)
            // --- Accessibility Features for Swift Student Challenge ---
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Color: \(color.description.capitalized)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
