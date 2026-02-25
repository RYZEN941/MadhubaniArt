import SwiftUI

extension Color {
    // ── Madhubani UI gold (used everywhere) ──────────────────────────────────
    static let mithilaGold    = Color(red: 208/255, green: 175/255, blue: 52/255)

    // ── Art surface (stays cream even in Dark Mode) ───────────────────────────
    static let handmadePaper  = Color(red: 0.96, green: 0.94, blue: 0.89)

    // ── Authentic pigment colors ──────────────────────────────────────────────
    static let deepVermillion = Color(red: 0.85, green: 0.23, blue: 0.18)
    static let turmericYellow = Color(red: 0.96, green: 0.70, blue: 0.00)
    static let indigoBlue     = Color(red: 0.17, green: 0.24, blue: 0.69)
    static let lampBlack      = Color(red: 0.05, green: 0.05, blue: 0.05)

    // ── Adaptive UI text (honors Dark Mode) ──────────────────────────────────
    static let uiPrimaryText   = Color.primary
    static let uiSecondaryText = Color.secondary
}
