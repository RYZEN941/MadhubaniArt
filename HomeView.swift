import SwiftUI

// MARK: - Main Home View
struct HomeView: View {
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = true
    @StateObject private var store = ProjectStore.shared
    @State private var isCreating        = false
    @State private var resumeProject     : SavedProject? = nil   // FIX #16: open saved project
    @State private var selectedLearnItem : LearnItem?  = nil
    @State private var selectedTheme     : ThemeItem?  = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(red:0.96,green:0.94,blue:0.89).ignoresSafeArea()
                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment:.leading, spacing:0) {
                            heroHeader
                                // top padding = real safe area so header sits just below status bar
                                .padding(.top, proxy.safeAreaInsets.top)
                            madhubaniDivider.padding(.top,4)
                            createNewSection.padding(.top,26)
                            madhubaniDivider.padding(.top,26)
                            learnSection.padding(.top,26)
                            madhubaniDivider.padding(.top,26)
                            themesSection.padding(.top,26)
                            Spacer(minLength:80)
                        }
                    }
                    // clip so content cannot scroll above the status bar
                    .clipped()
                }
            }
            .navigationBarHidden(true)
        }
        // FIX #16: pass resumeProject so CanvasView loads the real saved drawing
        .fullScreenCover(isPresented: $isCreating) {
            CanvasView(isPresented: $isCreating, resumeProject: resumeProject)
                .onDisappear { resumeProject = nil }
        }
        .fullScreenCover(isPresented: $hasFinishedOnboarding.not) {
            OnboardingView(hasFinishedOnboarding: $hasFinishedOnboarding)
        }
        .sheet(item: $selectedLearnItem) { LearnDetailModal(item: $0) }
        .sheet(item: $selectedTheme)    { ThemeDetailModal(item: $0) }
        .preferredColorScheme(.light)
    }

    // MARK: - Hero Header
    var heroHeader: some View {
        VStack(spacing:0) {
            // Decorative diamond row — replaces the old orange gradient stripe
            HStack(spacing:0) {
                ForEach(0..<44, id:\.self) { i in
                    Group {
                        if i%3==1 { Diamond().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.55)).frame(width:5,height:5) }
                        else       { Circle().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.2)).frame(width:3,height:3) }
                    }.frame(maxWidth:.infinity)
                }
            }
            .frame(height:12)

            HStack(alignment:.top) {
                VStack(alignment:.leading, spacing:6) {
                    Text("Mithila Studio")
                        .font(.custom("Georgia",size:36).bold())
                        .foregroundColor(Color(red:0.18,green:0.07,blue:0.01))
                    HStack(spacing:5) {
                        ForEach(0..<4,id:\.self) { _ in
                            Diamond().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.6))
                                .frame(width:5,height:5)
                        }
                        Text("Sacred Art of Bihar")
                            .font(.system(size:13,weight:.medium).italic())
                            .foregroundColor(Color(red:0.55,green:0.25,blue:0.03))
                        ForEach(0..<4,id:\.self) { _ in
                            Diamond().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.6))
                                .frame(width:5,height:5)
                        }
                    }
                }
                Spacer()
                Button(action:{ hasFinishedOnboarding = false }) {
                    Image(systemName:"info.circle").font(.system(size:18))
                        .foregroundColor(Color(red:0.55,green:0.30,blue:0.05).opacity(0.45))
                }.padding(.top,4)
            }
            .padding(.horizontal,24).padding(.top,16).padding(.bottom,20)
        }
    }

    var madhubaniDivider: some View {
        HStack(spacing:0) {
            ForEach(0..<55, id:\.self) { i in
                Group {
                    if i%3==1 { Diamond().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.45)).frame(width:5,height:5) }
                    else       { Circle().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.2)).frame(width:3,height:3) }
                }.frame(maxWidth:.infinity)
            }
        }.padding(.horizontal,24)
    }

    func sectionHeader(_ title:String, icon:String) -> some View {
        HStack(spacing:8) {
            Image(systemName:icon).font(.system(size:14,weight:.bold)).foregroundColor(.mithilaGold)
            Text(title).font(.custom("Georgia",size:22).bold()).foregroundColor(Color(red:0.18,green:0.07,blue:0.01))
        }.padding(.horizontal,24)
    }

    // MARK: - Create New (FIX #7: horizontal padding on artwork previews; FIX #16: open real project)
    var createNewSection: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader("Create New", icon:"paintbrush.pointed.fill")
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:16) {
                    // New Canvas button
                    Button(action:{ resumeProject = nil; isCreating = true }) {
                        VStack(spacing:10) {
                            ZStack {
                                Circle().fill(Color.mithilaGold.opacity(0.12)).frame(width:54,height:54)
                                Image(systemName:"plus").font(.system(size:22,weight:.bold)).foregroundColor(.mithilaGold)
                            }
                            Text("New Canvas").font(.system(size:13,weight:.bold)).foregroundColor(Color(red:0.22,green:0.09,blue:0.01))
                            Text("Start fresh").font(.system(size:10)).foregroundColor(Color(red:0.55,green:0.30,blue:0.05).opacity(0.7))
                        }
                        // FIX #7: explicit horizontal padding inside card
                        .padding(.horizontal,16)
                        .frame(width:160,height:160)
                        .background(madhubaniCardBg(r:20))
                    }

                    // FIX #16: saved projects — pass project to CanvasView so it actually loads
                    ForEach(store.projects.filter { !$0.isAutosave }) { project in
                        SavedProjectCard(
                            project: project,
                            thumbnail: store.thumbnail(for: project),
                            onOpen: {
                                resumeProject = project
                                isCreating = true
                            },
                            onDelete: { store.delete(project) }
                        )
                    }
                    Color.clear.frame(width:24,height:160)
                }
                // FIX #7: leading + trailing padding so cards don't touch screen edge
                .padding(.horizontal,24)
            }
        }
    }

    // MARK: - Learn
    var learnSection: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader("Learn", icon:"book.fill")
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:16) {
                    ForEach(LearnItem.all) { item in LearnCard(item:item) { selectedLearnItem = item } }
                    Color.clear.frame(width:24,height:160)
                }
                .padding(.horizontal,24)
            }
        }
    }

    // MARK: - Themes
    var themesSection: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader("Themes & Symbols", icon:"circle.hexagongrid.fill")
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:14) {
                    ForEach(ThemeItem.all) { item in ThemeCard(item:item) { selectedTheme = item } }
                    Color.clear.frame(width:24,height:130)
                }
                .padding(.horizontal,24)
            }
        }
    }
}

// Bool helper so we can use .not on @AppStorage Bool binding
extension Bool {
    var not: Bool { get { !self } set { self = !newValue } }
}

// MARK: - Saved Project Card
struct SavedProjectCard: View {
    let project   : SavedProject
    let thumbnail : UIImage?
    let onOpen    : () -> Void
    let onDelete  : () -> Void

    var dateStr: String {
        let f = DateFormatter(); f.dateStyle = .short
        return f.string(from: project.createdAt)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing:0) {
                // FIX #7: thumbnail has horizontal padding so it doesn't fill edge to edge
                ZStack {
                    if let img = thumbnail {
                        Image(uiImage:img)
                            .resizable().scaledToFill()
                            .frame(width:148,height:100).clipped()
                    } else {
                        Color(red:0.93,green:0.90,blue:0.83).frame(width:148,height:100)
                        Image(systemName:"paintbrush").font(.system(size:28))
                            .foregroundColor(Color.mithilaGold.opacity(0.4))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius:12, style:.continuous))
                .padding(.top,6).padding(.horizontal,6)   // FIX #7: left+right padding

                VStack(spacing:2) {
                    Text(project.title)
                        .font(.system(size:12,weight:.semibold))
                        .foregroundColor(Color(red:0.22,green:0.09,blue:0.01))
                        .lineLimit(1)
                    Text(dateStr)
                        .font(.system(size:9))
                        .foregroundColor(Color(red:0.55,green:0.28,blue:0.04).opacity(0.7))
                }
                .padding(.horizontal,8).padding(.vertical,6)
            }
            .frame(width:160,height:160)
            .background(madhubaniCardBg(r:20))
        }
        .contextMenu {
            Button(role:.destructive,action:onDelete) { Label("Delete",systemImage:"trash") }
        }
    }
}

// MARK: - Shared card background (FIX #5: single consistent border width = 1pt)
func madhubaniCardBg(r: CGFloat) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius:r,style:.continuous)
            .fill(Color(red:0.99,green:0.97,blue:0.91))
        RoundedRectangle(cornerRadius:r,style:.continuous)
            .stroke(Color.mithilaGold.opacity(0.55), lineWidth:1.5)
    }
    .shadow(color:Color(red:0.55,green:0.28,blue:0.00).opacity(0.08),radius:6,x:0,y:3)
}

// MARK: - Learn Card — image fills full card top, consistent 1.5pt gold border via madhubaniCardBg
struct LearnCard: View {
    let item:LearnItem; let action:()->Void
    private let assetNames = ["history_art","kachni_art","bharni_art","godna_art","tantrik_art","kohbar_art"]
    private var assetName: String {
        let idx = LearnItem.all.firstIndex(where:{ $0.id == item.id }) ?? 0
        return assetNames[idx % assetNames.count]
    }
    var body: some View {
        Button(action:action) {
            VStack(alignment:.leading, spacing:0) {
                // Portrait image fills top — taller so card looks like a painting
                ZStack {
                    Color(red:0.95,green:0.92,blue:0.84)
                    if UIImage(named:assetName) != nil {
                        Image(assetName)
                            .renderingMode(.original)
                            .resizable().scaledToFill()
                            .blendMode(.multiply)
                    } else {
                        Image(systemName:item.icon)
                            .font(.system(size:40)).foregroundColor(.mithilaGold.opacity(0.6))
                    }
                }
                .frame(width:140, height:160)  // portrait: taller than wide
                .clipped()

                // Title + subtitle
                VStack(alignment:.leading, spacing:2) {
                    Text(item.title)
                        .font(.custom("Georgia",size:13).bold())
                        .foregroundColor(Color(red:0.18,green:0.07,blue:0.01))
                    Text(item.subtitle)
                        .font(.system(size:10,weight:.medium))
                        .foregroundColor(Color(red:0.55,green:0.28,blue:0.04))
                }
                .padding(.horizontal,10).padding(.vertical,8)
            }
            .frame(width:140)
            .background(madhubaniCardBg(r:16))
            .clipShape(RoundedRectangle(cornerRadius:16,style:.continuous))
        }
    }
}

struct ThemeCard: View {
    let item:ThemeItem; let action:()->Void
    var body: some View {
        Button(action:action) {
            VStack(spacing:8) {
                ZStack {
                    Circle()
                        .fill(Color.mithilaGold.opacity(0.1))
                        .frame(width:62, height:62)
                    Circle()
                        .stroke(Color.mithilaGold.opacity(0.5), lineWidth:1.5)
                        .frame(width:62, height:62)
                    Image(systemName:item.icon)
                        .font(.system(size:26)).foregroundColor(.mithilaGold)
                }
                Text(item.title)
                    .font(.system(size:11,weight:.bold))
                    .foregroundColor(Color(red:0.18,green:0.07,blue:0.01))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width:100,height:110).background(madhubaniCardBg(r:16))
        }
    }
}

// MARK: - Learn Detail Modal with Glimpses (#11)
struct LearnDetailModal: View {
    let item:LearnItem; @Environment(\.dismiss) var dismiss

    // Glimpse images keyed by learn item title
    private var glimpses: [(icon:String, label:String)] {
        switch item.title {
        case "History":  return [("building.columns.fill","1934 Earthquake"),("globe.asia.australia.fill","Bihar, India"),("person.2.fill","Women artists"),("scroll.fill","On mud walls"),("star.fill","GI Tagged"),("checkmark.seal.fill","Living Heritage")]
        case "Kachni":   return [("pencil.line","Fine lines"),("minus","Hatching"),("circle.dotted","Stippling"),("paintpalette.fill","Black & Red"),("scribble.variable","No erasing"),("eye.fill","Precise detail")]
        case "Bharni":   return [("paintbrush.fill","Bold fills"),("drop.fill","Vivid pigments"),("sun.max.fill","Festival energy"),("house.fill","Brahmin art"),("rectangle.fill","Flat colour"),("sparkles","Decorative")]
        case "Godna":    return [("rhombus.fill","Geometric"),("circle.grid.3x3","Dot patterns"),("person.fill","Tribal roots"),("repeat","Repetition"),("grid","Dense forms"),("hexagon.fill","Sacred shapes")]
        case "Tantrik":  return [("star.of.david","Yantras"),("bolt.fill","Kali"),("moon.fill","Shakti"),("flame.fill","Shiva"),("circle.fill","Mandalas"),("infinity","Cosmic power")]
        case "Kohbar":   return [("heart.fill","Wedding art"),("fish.fill","Fish motif"),("leaf.fill","Lotus"),("tortoise.fill","Turtle"),("bird.fill","Paired birds"),("arrow.up.right","Bamboo")]
        default:         return [("paintbrush","Madhubani"),("leaf","Nature"),("sun.max","Sacred"),("star","Tradition"),("drop","Colour"),("circle","Pattern")]
        }
    }

    // FIX 1: 2 unique asset images per learn card, no names shown
    private var learnGlimpseImages: [String] {
        switch item.title {
        case "History":  return ["history1_art", "history2_art"]
        case "Kachni":   return ["kachni1_art",  "kachni2_art"]
        case "Bharni":   return ["bharni1_art",  "bharni2_art"]
        case "Godna":    return ["godna1_art",   "godna2_art"]
        case "Tantrik":  return ["tantrik1_art", "tantrik2_art"]
        case "Kohbar":   return ["kohbar1_art",  "kohbar2_art"]
        default:         return ["history1_art", "history2_art"]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading, spacing:0) {
                    // Art panel
                    ZStack {
                        Color(red:0.95,green:0.92,blue:0.84)
                        if UIImage(named:item.imageName) != nil {
                            Image(item.imageName).resizable().scaledToFit().blendMode(.multiply).padding(30)
                        } else {
                            Image(systemName:item.icon).font(.system(size:80)).foregroundColor(Color.mithilaGold.opacity(0.45))
                        }
                    }
                    .frame(maxWidth:.infinity).frame(height:220)

                    // Text
                    VStack(alignment:.leading, spacing:12) {
                        Text(item.subtitle.uppercased())
                            .font(.system(size:10,weight:.bold)).foregroundColor(.mithilaGold).tracking(2)
                        Text(item.description)
                            .font(.system(size:15)).lineSpacing(6).foregroundColor(Color(red:0.22,green:0.10,blue:0.02))
                    }.padding(24)

                    // Glimpses — 2 portrait images, no border, plain
                    VStack(alignment:.leading, spacing:10) {
                        Text("Glimpses")
                            .font(.system(size:13,weight:.bold)).foregroundColor(.mithilaGold)
                            .padding(.horizontal,24)
                        ScrollView(.horizontal, showsIndicators:false) {
                            HStack(spacing:16) {
                                ForEach(learnGlimpseImages, id:\.self) { assetName in
                                    if UIImage(named:assetName) != nil {
                                        Image(assetName)
                                            .renderingMode(.original)
                                            .resizable().scaledToFill()
                                            .frame(width:110, height:160)   // portrait
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius:10,style:.continuous))
                                    } else {
                                        // placeholder when image not yet added
                                        ZStack {
                                            RoundedRectangle(cornerRadius:10)
                                                .fill(Color(red:0.92,green:0.88,blue:0.80))
                                            Image(systemName:item.icon)
                                                .font(.system(size:38)).foregroundColor(.mithilaGold.opacity(0.5))
                                        }
                                        .frame(width:110, height:160)
                                    }
                                }
                            }
                            .padding(.horizontal,24)
                        }
                    }
                    .padding(.bottom,40)
                }
            }
            .background(Color(red:0.96,green:0.94,blue:0.89).ignoresSafeArea())
            .navigationTitle(item.title).navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done"){dismiss()}.fontWeight(.bold).foregroundColor(.mithilaGold) } }
        }
    }
}

// MARK: - Theme Detail Modal with Glimpses (#11)
struct ThemeDetailModal: View {
    let item:ThemeItem; @Environment(\.dismiss) var dismiss

    private var glimpses: [(icon:String, label:String)] {
        switch item.title {
        case "Mythology":  return [("scroll.fill","Ramayana"),("person.fill","Mahabharata"),("star.fill","Deities"),("flame.fill","Sacred fire"),("moon.stars.fill","Cosmos"),("crown.fill","Kings")]
        case "Marriage":   return [("heart.fill","Love"),("leaf.fill","Lotus"),("fish.fill","Fertility"),("tortoise.fill","Union"),("bird.fill","Paired birds"),("arrow.up.right","Bamboo")]
        case "Nature":     return [("sun.max.fill","Sun"),("moon.fill","Moon"),("leaf.fill","Trees"),("fish.fill","Fish"),("bird.fill","Birds"),("drop.fill","Water")]
        case "Fish":       return [("fish.fill","Prosperity"),("drop.fill","Flow"),("heart.fill","Fertility"),("sparkles","Fortune"),("circle.fill","Wholeness"),("arrow.left.and.right","Movement")]
        case "Lotus":      return [("camera.macro","Bloom"),("drop.fill","Purity"),("star.fill","Divine throne"),("leaf.fill","Nature"),("circle.fill","Perfection"),("sparkles","Awakening")]
        case "Peacock":    return [("bird.fill","Beauty"),("heart.fill","Love"),("star.fill","Grace"),("eye.fill","Watchful"),("sparkles","Joy"),("sun.max.fill","Pride")]
        case "Sun & Moon": return [("sun.max.fill","Life"),("moon.fill","Cycles"),("star.fill","Balance"),("circle.fill","Cosmos"),("bolt.fill","Energy"),("infinity","Eternal")]
        default:           return [("paintbrush","Madhubani"),("leaf","Nature"),("sun.max","Sacred"),("star","Symbol"),("drop","Colour"),("circle","Pattern")]
        }
    }

    // FIX 2: 2 unique asset images per theme card, no names shown
    private var themeGlimpseImages: [String] {
        switch item.title {
        case "Mythology":  return ["mythology1_art",  "mythology2_art"]
        case "Marriage":   return ["marriage1_art",   "marriage2_art"]
        case "Nature":     return ["nature1_art",     "nature2_art"]
        case "Fish":       return ["fish1_art",       "fish2_art"]
        case "Lotus":      return ["lotus1_art",      "lotus2_art"]
        case "Peacock":    return ["peacock1_art",    "peacock2_art"]
        case "Sun & Moon": return ["sunmoon1_art",    "sunmoon2_art"]
        case "Bamboo":     return ["bamboo1_art",     "bamboo2_art"]
        case "Turtle":     return ["turtle1_art",     "turtle2_art"]
        case "Snake":      return ["snake1_art",      "snake2_art"]
        default:           return ["peacock_art",     "lotus_art"]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:22) {
                    ZStack {
                        Circle().fill(Color.mithilaGold.opacity(0.08)).frame(width:120,height:120)
                        Circle().stroke(Color.mithilaGold.opacity(0.45),lineWidth:2.5).frame(width:120,height:120)
                        Circle().stroke(Color.mithilaGold.opacity(0.18),lineWidth:1).frame(width:108,height:108)
                        Image(systemName:item.icon).font(.system(size:52)).foregroundColor(.mithilaGold)
                    }.padding(.top,36)

                    VStack(spacing:6) {
                        Text(item.title).font(.custom("Georgia",size:26).bold()).foregroundColor(Color(red:0.18,green:0.07,blue:0.01))
                        Text("Symbol & Theme").font(.system(size:11,weight:.bold)).foregroundColor(.mithilaGold).tracking(2)
                    }

                    VStack(alignment:.leading,spacing:12) {
                        Text(item.description).font(.system(size:15)).lineSpacing(6)
                        Rectangle().fill(Color.mithilaGold.opacity(0.3)).frame(height:1)
                        Text("Cultural Significance").font(.system(size:13,weight:.bold)).foregroundColor(.mithilaGold)
                        Text(item.significance).font(.system(size:14)).foregroundColor(.secondary).lineSpacing(5)
                    }.padding(.horizontal,28)

                    // Glimpses — 2 portrait images, no border, plain
                    VStack(alignment:.leading, spacing:10) {
                        Text("Glimpses")
                            .font(.system(size:13,weight:.bold)).foregroundColor(.mithilaGold)
                            .padding(.horizontal,28)
                        ScrollView(.horizontal, showsIndicators:false) {
                            HStack(spacing:16) {
                                ForEach(themeGlimpseImages, id:\.self) { assetName in
                                    if UIImage(named:assetName) != nil {
                                        Image(assetName)
                                            .renderingMode(.original)
                                            .resizable().scaledToFill()
                                            .frame(width:110, height:160)   // portrait
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius:10,style:.continuous))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius:10)
                                                .fill(Color(red:0.92,green:0.88,blue:0.80))
                                            Image(systemName:item.icon)
                                                .font(.system(size:38)).foregroundColor(.mithilaGold.opacity(0.5))
                                        }
                                        .frame(width:110, height:160)
                                    }
                                }
                            }
                            .padding(.horizontal,28)
                        }
                    }
                    Spacer(minLength:40)
                }
            }
            .background(Color(red:0.96,green:0.94,blue:0.89).ignoresSafeArea())
            .navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done"){dismiss()}.fontWeight(.bold).foregroundColor(.mithilaGold) } }
        }
    }
}

// MARK: - Data Models
struct LearnItem: Identifiable {
    let id=UUID(); let title,subtitle,icon,imageName,description:String
    static let all:[LearnItem] = [
        LearnItem(title:"History",  subtitle:"Origins",         icon:"clock.fill",          imageName:"history_art",  description:"Madhubani painting originates from the Mithila region of Bihar. Practiced for centuries on mud walls during rituals, it gained global recognition after the 1934 earthquake. Today it is a GI-tagged art form."),
        LearnItem(title:"Kachni",   subtitle:"Line Work",       icon:"pencil.and.outline",  imageName:"kachni_art",   description:"Kachni uses fine, precise line work with minimal color — primarily black and red. Artists build texture through hatching and stippling. Every stroke is deliberate; there is no erasing."),
        LearnItem(title:"Bharni",   subtitle:"Bold Fills",      icon:"paintbrush.fill",     imageName:"bharni_art",   description:"Bharni means 'to fill.' Artists outline subjects then fill with vibrant pigments — blue, yellow, red, green. Originating in Brahmin households, it is known for festive energy."),
        LearnItem(title:"Godna",    subtitle:"Tattoo Style",    icon:"rhombus.fill",        imageName:"godna_art",    description:"Godna is inspired by traditional tattoo patterns of Bihar's tribal communities. It features repetitive geometric patterns and dots arranged in dense formations."),
        LearnItem(title:"Tantrik",  subtitle:"Sacred Geometry", icon:"star.of.david",       imageName:"tantrik_art",  description:"Tantrik Madhubani depicts deities in fierce forms — Kali, Shiva, Shakti — surrounded by sacred geometric patterns and yantras radiating from a central divine figure."),
        LearnItem(title:"Kohbar",   subtitle:"Wedding Art",     icon:"heart.fill",          imageName:"kohbar_art",   description:"Kohbar paintings are made for wedding ceremonies, dense with fertility symbols — bamboo, fish, lotus, turtles, and paired birds."),
    ]
}
struct ThemeItem: Identifiable {
    let id=UUID(); let title,icon,description,significance:String
    static let all:[ThemeItem] = [
        ThemeItem(title:"Mythology",  icon:"scroll.fill",    description:"Scenes from the Ramayana and Mahabharata dominate Mithila art.",             significance:"Connects daily life to Hindu cosmology and moral values."),
        ThemeItem(title:"Marriage",   icon:"heart.fill",     description:"Kohbar paintings packed with lotus, bamboo, fish, turtles.",                  significance:"Painted in the Kohbar Ghar to sanctify the wedding chamber."),
        ThemeItem(title:"Nature",     icon:"leaf.fill",      description:"Sun, moon, bamboo, trees, birds and fish express our bond with nature.",       significance:"In Mithila philosophy, Prakriti (nature) is divine."),
        ThemeItem(title:"Fish",       icon:"fish.fill",      description:"The fish swims through wedding art and ritual compositions.",                  significance:"Symbolizes fertility, prosperity, and the flow of life."),
        ThemeItem(title:"Lotus",      icon:"camera.macro",   description:"The lotus blooms in mud yet remains pristine — throne of deities.",           significance:"Represents divine purity and spiritual awakening."),
        ThemeItem(title:"Peacock",    icon:"bird.fill",      description:"Peacocks appear in Kohbar paintings, dancing or paired.",                     significance:"Represents beauty, grace, love, and joy."),
        ThemeItem(title:"Sun & Moon", icon:"sun.max.fill",   description:"Sun and moon are cosmic witnesses at the top of compositions.",               significance:"Represent life, cosmic balance, and masculine/feminine forces."),
        ThemeItem(title:"Bamboo",     icon:"arrow.up.right", description:"Bamboo groves are a staple of Kohbar art.",                                   significance:"Symbolizes lineage, strength, and continuity."),
        ThemeItem(title:"Turtle",     icon:"tortoise.fill",  description:"The turtle appears in wedding paintings.",                                    significance:"Symbolizes the enduring union of lovers."),
        ThemeItem(title:"Snake",      icon:"waveform.path",  description:"Serpents coil through Madhubani as guardian spirits.",                        significance:"Represents protection from evil and the cycle of renewal."),
    ]
}
