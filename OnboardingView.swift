import SwiftUI

struct OnboardingView: View {
    @Binding var hasFinishedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardPage] = [
        OnboardPage(title:"Mithila", subtitle:"The Art of Bihar",
            body:"For over 2,500 years, women in the Mithila region of Bihar have painted sacred designs on walls, floors, and cloth — celebrating life, nature, and the divine.",
            motifSymbol:"sun.max.fill", accentColor:Color(red:0.85,green:0.23,blue:0.18)),
        OnboardPage(title:"Sacred Symbols", subtitle:"Every stroke carries meaning",
            body:"The fish brings prosperity. The lotus speaks of purity. The peacock sings of love. Each motif is a visual prayer, passed from mother to daughter across generations.",
            motifSymbol:"fish.fill", accentColor:Color(red:0.17,green:0.24,blue:0.69)),
        OnboardPage(title:"Your Canvas", subtitle:"Begin your own tradition",
            body:"Draw with traditional colors. Place sacred motifs. Learn the art styles — Kachni, Bharni, Godna. Preserve this living heritage one stroke at a time.",
            motifSymbol:"pencil.tip", accentColor:Color(red:0.60,green:0.20,blue:0.05)),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(red:0.96,green:0.93,blue:0.85).ignoresSafeArea()

                // FIX #3 #6: decorative borders INSIDE safe area, rounded corners
                decorativeBorders(geo:geo)

                VStack(spacing:0) {
                    Spacer()
                    TabView(selection:$currentPage) {
                        ForEach(0..<pages.count, id:\.self) { i in
                            pageView(pages[i]).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode:.never))
                    .frame(height:480)
                    .animation(.easeInOut(duration:0.35), value:currentPage)

                    Spacer()

                    // Dots
                    HStack(spacing:10) {
                        ForEach(0..<pages.count, id:\.self) { i in
                            Capsule()
                                .fill(i==currentPage
                                      ? Color(red:0.75,green:0.45,blue:0.05)
                                      : Color(red:0.75,green:0.45,blue:0.05).opacity(0.25))
                                .frame(width:i==currentPage ? 24:8, height:8)
                                .animation(.spring(response:0.3), value:currentPage)
                        }
                    }.padding(.bottom,24)

                    // CTA button
                    Button(action:{
                        if currentPage < pages.count - 1 { withAnimation { currentPage += 1 } }
                        else { withAnimation { hasFinishedOnboarding = true } }
                    }) {
                        HStack(spacing:8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Start Painting")
                                .font(.system(size:17,weight:.bold))
                            Image(systemName:currentPage < pages.count - 1 ? "arrow.right" : "paintbrush.fill")
                                .font(.system(size:15,weight:.bold))
                        }
                        .foregroundColor(Color(red:0.96,green:0.93,blue:0.85))
                        .frame(width:220,height:54)
                        .background(
                            RoundedRectangle(cornerRadius:16)
                                .fill(Color(red:0.55,green:0.22,blue:0.03))
                                .overlay(RoundedRectangle(cornerRadius:16)
                                    .stroke(Color(red:0.85,green:0.55,blue:0.10),lineWidth:1.5))
                        )
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 40)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // FIX #3 #6: borders inside safe area with corner radius 20
    func decorativeBorders(geo: GeometryProxy) -> some View {
        let top    = geo.safeAreaInsets.top
        let bottom = geo.safeAreaInsets.bottom
        return ZStack {
            RoundedRectangle(cornerRadius:20)
                .stroke(
                    LinearGradient(
                        colors:[Color(red:0.85,green:0.55,blue:0.10).opacity(0.65),
                                Color(red:0.85,green:0.23,blue:0.18).opacity(0.45),
                                Color(red:0.85,green:0.55,blue:0.10).opacity(0.65)],
                        startPoint:.topLeading, endPoint:.bottomTrailing),
                    lineWidth:2.5)
                .padding(EdgeInsets(top:top+10, leading:12, bottom:bottom+10, trailing:12))
            RoundedRectangle(cornerRadius:16)
                .stroke(Color(red:0.85,green:0.55,blue:0.10).opacity(0.2), lineWidth:1)
                .padding(EdgeInsets(top:top+18, leading:20, bottom:bottom+18, trailing:20))
        }
        .ignoresSafeArea()   // let it size to full screen but insets push rect in
    }

    func pageView(_ page: OnboardPage) -> some View {
        VStack(spacing:28) {
            ZStack {
                Circle().fill(page.accentColor.opacity(0.08)).frame(width:130,height:130)
                Circle().stroke(AngularGradient(
                    colors:[page.accentColor,Color(red:0.85,green:0.60,blue:0.10),page.accentColor],
                    center:.center),lineWidth:2.5).frame(width:130,height:130)
                Circle().stroke(page.accentColor.opacity(0.25),lineWidth:1).frame(width:118,height:118)
                ForEach(0..<12, id:\.self) { i in
                    let angle = Double(i)/12.0*2*Double.pi
                    Circle().fill(page.accentColor.opacity(0.5)).frame(width:4,height:4)
                        .offset(x:63*CGFloat(cos(angle)), y:63*CGFloat(sin(angle)))
                }
                Image(systemName:page.motifSymbol).font(.system(size:48,weight:.medium))
                    .foregroundColor(page.accentColor)
            }

            VStack(spacing:10) {
                Text(page.title).font(.custom("Georgia",size:34).bold())
                    .foregroundColor(Color(red:0.18,green:0.08,blue:0.02))
                Text(page.subtitle).font(.system(size:16,weight:.medium).italic())
                    .foregroundColor(page.accentColor)
                HStack(spacing:4) {
                    ForEach(0..<7,id:\.self) { _ in
                        Diamond().fill(Color(red:0.75,green:0.45,blue:0.05).opacity(0.5)).frame(width:6,height:6)
                    }
                }.padding(.vertical,4)
                Text(page.body).font(.system(size:15))
                    .foregroundColor(Color(red:0.28,green:0.15,blue:0.05))
                    .multilineTextAlignment(.center).lineSpacing(5).padding(.horizontal,36)
            }
        }
    }
}

struct OnboardPage {
    let title, subtitle, body, motifSymbol: String
    let accentColor: Color
}
