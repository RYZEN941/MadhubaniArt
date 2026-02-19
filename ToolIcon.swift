import SwiftUI

struct ToolIcon: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundColor(isActive ? .deepVermillion : .lampBlack.opacity(0.7))
        }
    }
}
