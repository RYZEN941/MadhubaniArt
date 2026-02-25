//import SwiftUI
//
//struct MotifGallery: View {
//    @Environment(\.dismiss) var dismiss
//    
//    let customMotifs = [
//        ("peacock_art", "Peacock"),
//        ("fish_art", "Fish"),
//        ("lotus_art", "Lotus"),
//        ("sun_art", "Sun")
//    ]
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
//                    ForEach(customMotifs, id: \.0) { motif in
//                        Button(action: {
//                            NotificationCenter.default.post(name: NSNotification.Name("DropMotif"), object: motif.0)
//                            dismiss()
//                        }) {
//                            VStack {
//                                ZStack {
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(Color.white)
//                                        .shadow(color: .black.opacity(0.1), radius: 3)
//                                    
//                                    // FIX: renderingMode MUST be before resizable
//                                    Image(motif.0)
//                                        .renderingMode(.original)
//                                        .resizable()
//                                        .scaledToFit()
//                                        .padding(10)
//                                        .background(
//                                            // Diagnostic check: Shows if file name is wrong
//                                            Text(UIImage(named: motif.0) == nil ? "NOT FOUND" : "")
//                                                .font(.caption2).foregroundColor(.red)
//                                        )
//                                }
//                                .frame(width: 100, height: 100)
//                                
//                                Text(motif.1)
//                                    .font(.caption.bold())
//                                    .foregroundColor(.primary)
//                            }
//                        }
//                    }
//                }
//                .padding()
//            }
//            .navigationTitle("Sacred Motifs")
//            .background(Color(UIColor.secondarySystemBackground))
//        }
//    }
//}
import SwiftUI

struct MotifGallery: View {
    @Environment(\.dismiss) var dismiss

    let customMotifs = [
        ("peacock_art", "Peacock"),
        ("fish_art",    "Fish"),
        ("lotus_art",   "Lotus"),
        ("sun_art",     "Sun")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
                    ForEach(customMotifs, id: \.0) { motif in
                        Button(action: {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DropMotif"),
                                object: motif.0
                            )
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    // Card background — cream like the canvas
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(red: 0.96, green: 0.94, blue: 0.89))
                                        .shadow(color: .black.opacity(0.08), radius: 4)

                                    if UIImage(named: motif.0) != nil {
                                        Image(motif.0)
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(12)
                                            // KEY FIX: makes black pixels invisible on light bg
                                            // Black lines show as black, white/light areas disappear
                                            .blendMode(.multiply)
                                    } else {
                                        // Friendly fallback — shows icon instead of red error text
                                        VStack(spacing: 4) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 28))
                                                .foregroundColor(.secondary.opacity(0.4))
                                            Text("Add to Assets")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                                .frame(width: 100, height: 100)

                                Text(motif.1)
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sacred Motifs")
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}
