import SwiftUI

struct HomeView: View {
    @State private var isCreating = false
    @State private var selectedDetail: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    headerSection
                    createNewSection
                    learnSection
                    themesSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
            // Light-mode friendly background
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $isCreating) {
            CanvasView(isPresented: $isCreating)
        }
        .sheet(item: Binding(
            get: { selectedDetail.map { IdentifiableString(id: $0) } },
            set: { selectedDetail = $0?.id }
        )) { detail in
            ModalDetailView(title: detail.id)
        }
    }
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mithila Studio")
                .font(.custom("Georgia", size: 36).bold())
            Text("A sacred journey through Bihar's heritage")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 30)
    }
    
    var createNewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create New").font(.title2.bold())
            ZStack(alignment: .trailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        Button(action: { isCreating = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.mithilaGold) // Global color access
                                Text("New Canvas").font(.caption).bold().foregroundColor(.primary)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.05), radius: 8)
                        }
                        ProjectCard(title: "Arjuna's Chariot")
                        ProjectCard(title: "Lotus Pond")
                    }
                    .padding(.trailing, 40)
                }
                SectionChevronHint()
            }
        }
    }

    var learnSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Art Styles").font(.title2.bold())
            ZStack(alignment: .trailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        SquareCategoryCard(title: "Kachni", subtitle: "Line Work", icon: "pencil.and.outline") { selectedDetail = "Kachni" }
                        SquareCategoryCard(title: "Bharni", subtitle: "Bold Fills", icon: "paintbrush.fill") { selectedDetail = "Bharni" }
                        SquareCategoryCard(title: "Godna", subtitle: "Tattoo Style", icon: "rhombus.fill") { selectedDetail = "Godna" }
                    }
                    .padding(.trailing, 40)
                }
                SectionChevronHint()
            }
        }
    }

    var themesSection: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text("Themes & Symbols").font(.title2.bold())
                ZStack(alignment: .trailing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            // --- CORE THEMES ---
                            ThemeSquare(title: "Mythology", icon: "scroll.fill") { selectedDetail = "Mythological" }
                            ThemeSquare(title: "Marriage", icon: "heart.fill") { selectedDetail = "Kohbar" }
                            ThemeSquare(title: "Social", icon: "person.2.fill") { selectedDetail = "Social" }
                            ThemeSquare(title: "Nature", icon: "leaf.fill") { selectedDetail = "Nature" }
                            
                            // --- MAJOR SYMBOLS ---
                            ThemeSquare(title: "Fish", icon: "fish.fill") { selectedDetail = "Fish" }
                            ThemeSquare(title: "Peacock", icon: "bird.fill") { selectedDetail = "Peacock" }
                            ThemeSquare(title: "Lotus", icon: "camera.macro") { selectedDetail = "Lotus" }
                            ThemeSquare(title: "Sun", icon: "sun.max.fill") { selectedDetail = "Sun" }
                            ThemeSquare(title: "Elephant", icon: "laurel.leading") { selectedDetail = "Elephant" }
                        }
                        .padding(.trailing, 40)
                    }
                    SectionChevronHint() // The horizontal "heron" hint
                }
            }
        }}

// MARK: - Reusable Components

struct SquareCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.mithilaGold) // Correctly finds global color
                Spacer()
                Text(title).font(.headline).foregroundColor(.primary)
                Text(subtitle).font(.caption2).foregroundColor(.secondary)
            }
            .padding(20)
            .frame(width: 150, height: 150)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
        }
    }
}

struct ThemeSquare: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.mithilaGold)
                    .padding(.bottom, 8)
                Text(title).font(.callout.bold()).foregroundColor(.primary)
            }
            .frame(width: 150, height: 150)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
        }
    }
}

struct ProjectCard: View {
    let title: String
    var body: some View {
        VStack {
            Spacer()
            Text(title).font(.caption).bold()
                .foregroundColor(.primary)
                .padding(.bottom, 15)
        }
        .frame(width: 150, height: 150)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
    }
}

struct SectionChevronHint: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.secondary.opacity(0.3))
            .padding(.trailing, 4)
            .allowsHitTesting(false)
    }
}

// MARK: - GLOBAL ACCENT COLOR DEFINITION
extension Color {
    static let mithilaGold = Color(red: 208/255, green: 175/255, blue: 52/255) // rgb(208, 175, 52)
}

// MARK: - Helpers
struct IdentifiableString: Identifiable {
    let id: String
}

struct ModalDetailView: View {
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large Hero Icon in Mithila Gold
                Image(systemName: iconForTitle(title))
                    .font(.system(size: 100))
                    .foregroundColor(.mithilaGold.opacity(0.8))
                    .padding(.top, 40)
                
                Text(title)
                    .font(.custom("Georgia", size: 32).bold())
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(descriptionForTitle(title))
                        .font(.body)
                        .lineSpacing(6)
                    
                    Text("Cultural Significance")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text(significanceForTitle(title))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .background(Color(UIColor.systemBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(.mithilaGold)
                }
            }
        }
    }

    // MARK: - Content Helper Functions
    
    func iconForTitle(_ title: String) -> String {
        switch title {
        case "Kachni": return "pencil.and.outline"
        case "Bharni": return "paintbrush.fill"
        case "Fish": return "fish.fill"
        case "Lotus": return "camera.macro"
        case "Sun": return "sun.max.fill"
        case "Peacock": return "bird.fill"
        case "Elephant": return "laurel.leading"
        case "Mythology": return "scroll.fill"
        case "Nature": return "leaf.fill"
        default: return "photo.artframe"
        }
    }

    func descriptionForTitle(_ title: String) -> String {
        switch title {
        case "Kachni": return "The Kachni style is characterized by fine, intricate line work. Artists use only a few colors—usually black and red—to create detailed textures through hatching and stippling."
        case "Bharni": return "Bharni means 'to fill.' This style is known for vibrant, bold colors. Artists first outline the subjects and then fill them with rich pigments like blue, yellow, and green."
        case "Fish": return "The fish is one of the most common motifs in Mithila art. It represents fertility, abundance, and the flow of life in the ponds of Bihar."
        case "Lotus": return "The Lotus symbolizes purity and the divine presence. It is often depicted as the seat of deities, blooming even in the mud of worldly attachments."
        case "Sun": return "The Sun represents the source of all life and energy. In Mithila traditions, it is often drawn with a fierce and powerful face to symbolize protection."
        case "Peacock": return "Peacocks symbolize beauty, grace, and romantic love. They are frequently painted in Kohbar (marriage) scenes to bless the couple with happiness."
        default: return "This sacred motif carries centuries of tradition from the Mithila region of Bihar, connecting art to the rhythm of nature and spirituality."
        }
    }

    func significanceForTitle(_ title: String) -> String {
        switch title {
        case "Kachni":
            return "Represents the technical precision of the Kayastha tradition, focusing on the purity of line."
        case "Bharni":
            return "Originating from the Brahmin tradition, it symbolizes the vibrant fullness and color of life."
        case "Fish":
            return "Used in wedding invitations to bless the couple with many children and a life of plenty."
        case "Lotus":
            return "Represents the feminine energy and is a core symbol of the Kohbar (marriage) chamber."
        case "Sun":
            return "A witness to all actions on earth; it is essential in Madhubani art to maintain cosmic order."
        case "Peacock":
            return "Considered a divine messenger and a symbol of romantic fidelity in Mithila folklore."
        case "Elephant":
            return "Signifies the arrival of Ganesha, bringing wisdom and the removal of all obstacles."
        case "Mythology":
            return "Connects the daily life of Bihar to the epic tales of the Ramayana and Mahabharata."
        case "Nature":
            return "Reflects the 'Prakriti' (Nature) which Mithila artists believe is inseparable from the human spirit."
        default:
            return "A sacred symbol of the shared identity and artistic heritage of the Mithila community."
        }
    }}
