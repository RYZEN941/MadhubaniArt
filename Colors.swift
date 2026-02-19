import SwiftUI

extension Color {
    // AUTHENTIC ART COLORS (These never change)
    static let deepVermillion = Color(red: 0.85, green: 0.23, blue: 0.18)
    static let turmericYellow = Color(red: 0.96, green: 0.70, blue: 0.00)
    static let indigoBlue = Color(red: 0.17, green: 0.24, blue: 0.69)
    static let lampBlack = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    // THE ART SURFACE (Stays Cream/Off-white even in Dark Mode)
    static let handmadePaper = Color(red: 0.96, green: 0.94, blue: 0.89)
    
    // UI TEXT COLORS (These adapt so they are always visible)
    static let uiPrimaryText = Color.primary // White in Dark Mode, Black in Light Mode
    static let uiSecondaryText = Color.secondary // Light Gray in Dark Mode, Dark Gray in Light Mode
}
