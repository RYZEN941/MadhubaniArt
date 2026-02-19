import SwiftUI

struct MotifGallery: View {
    @Environment(\.dismiss) var dismiss
    
    let customMotifs = [
        ("peacock_art", "Peacock"),
        ("fish_art", "Fish"),
        ("lotus_art", "Lotus"),
        ("sun_art", "Sun")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                    ForEach(customMotifs, id: \.0) { motif in
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("DropMotif"), object: motif.0)
                            dismiss()
                        }) {
                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.1), radius: 3)
                                    
                                    // FIX: renderingMode MUST be before resizable
                                    Image(motif.0)
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(10)
                                        .background(
                                            // Diagnostic check: Shows if file name is wrong
                                            Text(UIImage(named: motif.0) == nil ? "NOT FOUND" : "")
                                                .font(.caption2).foregroundColor(.red)
                                        )
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
