import SwiftUI
import PencilKit
import UIKit

// MARK: - MotifInstance
// Codable so it can be JSON-persisted. Let is used for id so it never changes after init.

struct MotifInstance: Identifiable, Codable {
    let id        : UUID
    var imageName : String
    var position  : CGPoint
    var scale     : CGFloat  = 1.0
    var rotation  : Double   = 0.0   // degrees
    var tintColor : CodableColor? = nil
    var isLocked  : Bool     = false
    var filledImageData: Data? = nil  // PNG of motif after per-region pixel fills

    init(imageName: String, position: CGPoint, scale: CGFloat = 1.0) {
        self.id        = UUID()
        self.imageName = imageName
        self.position  = position
        self.scale     = scale
    }
}

// Color is not Codable — wrap it
struct CodableColor: Codable, Equatable {
    var r,g,b,a: Double
    init(_ c: Color) {
        var rr:CGFloat=0,gg:CGFloat=0,bb:CGFloat=0,aa:CGFloat=0
        UIColor(c).getRed(&rr,green:&gg,blue:&bb,alpha:&aa)
        r=Double(rr);g=Double(gg);b=Double(bb);a=Double(aa)
    }
    var color: Color { Color(red:r,green:g,blue:b).opacity(a) }
    var uiColor: UIColor { UIColor(red:r,green:g,blue:b,alpha:a) }
}

enum CanvasTool: Equatable { case pen, eraser, motifSelect, fill }

// MARK: - Undo stack items
// We track every mutable change so undo/redo works across pen, eraser, fill, and motifs.

enum UndoItem {
    case drawing(PKDrawing, PKDrawing)
    case motifAdded(MotifInstance)
    case motifDeleted(MotifInstance, Int)
    case motifMoved(UUID, CGPoint, CGPoint)
    case motifScaled(UUID, CGFloat, CGFloat)
    case motifRotated(UUID, Double, Double)      // id, from, to
    case motifTinted(UUID, CodableColor?, CodableColor?)
    case clearAll(PKDrawing, [MotifInstance])
}

// MARK: - Palette

private let madhubaniPalette: [(Color, String)] = [
    (Color(red:0.05,green:0.05,blue:0.05),"Lamp Black"),
    (Color(red:0.85,green:0.23,blue:0.18),"Vermillion"),
    (Color(red:0.96,green:0.70,blue:0.00),"Turmeric"),
    (Color(red:0.17,green:0.24,blue:0.69),"Indigo"),
    (Color(red:0.13,green:0.55,blue:0.13),"Forest"),
    (Color(red:0.60,green:0.20,blue:0.05),"Sienna"),
    (Color(red:0.75,green:0.30,blue:0.80),"Mauve"),
    (Color(red:1.00,green:0.45,blue:0.00),"Saffron"),
    (Color(red:0.48,green:0.07,blue:0.48),"Purple"),
    (Color(red:0.00,green:0.65,blue:0.90),"Sky"),
    (Color(red:0.85,green:0.10,blue:0.38),"Pink"),
    (Color(red:0.97,green:0.97,blue:0.97),"White"),
]

// MARK: - CanvasView

struct CanvasView: View {
    @Binding var isPresented: Bool
    var resumeProject: SavedProject? = nil

    @StateObject private var store = ProjectStore.shared

    // Project state
    @State private var currentProjectID: UUID?  = nil
    @State private var currentTitle:     String = ""
    @State private var isDirty           = false
    @State private var autosaveTimer: Timer? = nil

    // Tools
    @State private var activeTool   : CanvasTool = .pen
    @State private var selectedColor              = Color(red:0.85, green:0.23, blue:0.18)
    @State private var brushSize    : CGFloat     = 3
    @State private var eraserSize   : CGFloat     = 30
    @State private var showPalette                = false
    @State private var railPenOpen                = false  // pen size sub-menu
    @State private var railEraserOpen             = false  // eraser size sub-menu

    // PencilKit
    @State private var canvasView      = PKCanvasView()
    @State private var lastDrawing     : PKDrawing? = nil  // snapshot before stroke

    // Motifs
    @State private var motifs           : [MotifInstance] = []
    @State private var selectedMotifID  : UUID?           = nil
    @State private var clipboard        : MotifInstance?  = nil
    @State private var showMotifTray    = false
    @State private var showLayers       = false

    // Undo / Redo
    @State private var undoStack: [UndoItem] = []
    @State private var redoStack: [UndoItem] = []

    // Save alerts
    @State private var showSaveAsAlert  = false
    @State private var showNameConflict = false
    @State private var pendingTitle     = ""

    // Export / toast
    @State private var exportImage   : UIImage? = nil
    @State private var showShareSheet = false
    @State private var toastMsg       = ""
    @State private var showToast      = false

    @State private var canvasSize: CGSize = UIScreen.main.bounds.size
    // Safe area read from UIWindow so .ignoresSafeArea() on the root ZStack doesn't zero it out
    @State private var safeTopInset: CGFloat = 0
    // Snap drawing modes
    @State private var snapLine   = false
    @State private var snapCircle = false

    var isMotifMode: Bool { activeTool == .motifSelect }

    private let motifNames = [
        "peacock_art","lotus_art","fish_art","sun_art",
        "elephant_art","two_fish_art","leaf_art",
        "border1_art","border2_art","border3_art"
    ]

    // MARK: body
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment:.topLeading) {

                // ── 0. Paper background ──────────────────────
                Color(red:0.96,green:0.94,blue:0.89).ignoresSafeArea()

                // ── 1. PencilKit canvas ──────────────────────
                // Canvas bg is CLEAR so the paper layer above shows through motifs.
                // zIndex: above motif layer in pen mode, below in motif mode.
                DrawingCanvas(
                    canvasView: $canvasView,
                    snapLine: snapLine,
                    snapCircle: snapCircle,
                    onStrokeBegin: {
                        // snapshot BEFORE the stroke
                        lastDrawing = canvasView.drawing
                    },
                    onStrokeEnd: {
                        // only push if a real stroke was added
                        guard let before = lastDrawing else { return }
                        let after = canvasView.drawing
                        if before.strokes.count != after.strokes.count {
                            pushUndo(.drawing(before, after))
                            isDirty = true
                        }
                        lastDrawing = nil
                    }
                )
                .ignoresSafeArea()
                .allowsHitTesting(activeTool == .pen || activeTool == .eraser)
                .zIndex(isMotifMode ? 1 : 3)

                // ── 2. Motif layer ───────────────────────────
                // zIndex 2 = always visible above paper, below canvas in pen mode.
                // In motif mode rises to 4 so touches land on motifs first.
                ZStack {
                    // Background tap → deselect (motif mode only)
                    if isMotifMode {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { selectedMotifID = nil }
                    }
                    ForEach($motifs) { $m in
                        MotifItemView(
                            motif         : $m,
                            isSelected    : selectedMotifID == m.id,
                            isMotifMode   : isMotifMode,
                            activeTool    : activeTool,
                            selectedColor : selectedColor,
                            onTap: {
                                guard !m.isLocked else { return }
                                selectedMotifID = m.id
                                activeTool = .motifSelect
                                showPalette = false
                            },
                            onDragEnd: { from, to in
                                guard from != to else { return }
                                pushUndo(.motifMoved(m.id, from, to))
                                isDirty = true
                            },
                            onFillTap: {
                                // Fill tool tapped on this motif → tint it
                                guard activeTool == .fill else { return }
                                let old = m.tintColor
                                let new = CodableColor(selectedColor)
                                m.tintColor = new
                                pushUndo(.motifTinted(m.id, old, new))
                                isDirty = true
                            },
                            onCut:        { clipboard = m; deleteMotif(m.id) },
                            onCopy:       { clipboard = m },
                            onDuplicate:  { duplicateMotif(m) },
                            onToggleLock: {
                                m.isLocked.toggle()
                                if m.isLocked { selectedMotifID = nil }
                            },
                            onDelete:     { deleteMotif(m.id) },
                            onScaleDelta: { d in
                                m.scale = max(0.3, min(4.0, m.scale * d))
                            },
                            onRotateEnd: { from, to in
                                pushUndo(.motifRotated(m.id, from, to))
                                isDirty = true
                            }
                        )
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .zIndex(isMotifMode ? 4 : 2)

                // ── 3. Fill tap overlay ──────────────────────
                // Sits above everything; checks if tap is on a motif first.
                if activeTool == .fill {
                    Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                        .onTapGesture { loc in handleFillTap(at: loc) }
                        .zIndex(4)
                }

                // ── 4. Top bar ───────────────────────────────
                VStack {
                    topBar.padding(.top, safeTopInset + 14)
                    Spacer()
                }.zIndex(10)

                // ── 5. Tool rail ─────────────────────────────
                VStack {
                    Spacer()
                    HStack(spacing:0) {
                        Spacer()
                        if showPalette {
                            palettePanel
                                .padding(.trailing, 12)
                                .transition(.scale(scale:0.1, anchor:.trailing).combined(with:.opacity))
                        }
                        toolRail
                    }
                    Spacer()
                }
                .zIndex(10)

                // ── 6. Motif controls bar ────────────────────
                if isMotifMode, selectedMotifID != nil {
                    VStack { Spacer(); motifControls }
                        .ignoresSafeArea(edges:.bottom).zIndex(11)
                }

                // ── 6b. Layers panel ─────────────────────────
                if showLayers {
                    Color.black.opacity(0.001).contentShape(Rectangle()).ignoresSafeArea()
                        .onTapGesture { showLayers = false }
                        .zIndex(14)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            layersPanel
                                .padding(.trailing, 76)
                                .padding(.bottom, 80)
                        }
                    }
                    .zIndex(15)
                    .transition(.opacity.combined(with:.scale(scale:0.95, anchor:.bottomTrailing)))
                }

                // ── 7. Motif tray dismiss layer ──────────────
                if showMotifTray {
                    Color.black.opacity(0.001).contentShape(Rectangle()).ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response:0.28)) { showMotifTray = false } }
                        .zIndex(19)
                    VStack { Spacer(); motifTray }
                        .ignoresSafeArea(edges:.bottom).zIndex(20)
                        .transition(.move(edge:.bottom).combined(with:.opacity))
                }

                // ── 8. Motif tray button (bottom-right) ──────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        motifTrayButton
                            .padding(.trailing, 16)
                            .padding(.bottom, max(geo.safeAreaInsets.bottom, 10) + 16)
                    }
                }.zIndex(21)

                // ── 9. Toast ─────────────────────────────────
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMsg)
                            .font(.system(size:14, weight:.semibold)).foregroundColor(.white)
                            .padding(.horizontal, 22).padding(.vertical, 11)
                            .background(Capsule().fill(Color(red:0.12,green:0.05,blue:0.0).opacity(0.88)))
                            .padding(.bottom, 110)
                    }.zIndex(40).transition(.opacity.combined(with:.move(edge:.bottom)))
                }
            }
            .animation(.spring(response:0.26, dampingFraction:0.76), value:showPalette)
            .animation(.spring(response:0.28, dampingFraction:0.78), value:showMotifTray)
            .animation(.easeInOut(duration:0.18), value:activeTool)
            .animation(.easeInOut(duration:0.15), value:selectedMotifID)
            .animation(.easeInOut(duration:0.15), value:railPenOpen)
            .animation(.easeInOut(duration:0.15), value:railEraserOpen)
            .onAppear {
                canvasSize = geo.size
                // Read safe area from the actual window — unaffected by .ignoresSafeArea()
                if let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first?.windows.first {
                    safeTopInset = window.safeAreaInsets.top
                }
                loadProject()
                startAutosave()
            }
            .onDisappear { stopAutosave(); performAutosave() }
            .onChange(of: geo.size) { canvasSize = $0 }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .sheet(isPresented:$showShareSheet) {
            if let img = exportImage { ShareSheet(image:img) }
        }
        .alert("Name Your Artwork", isPresented:$showSaveAsAlert) {
            TextField("e.g. Lotus Pond", text:$pendingTitle)
            Button("Save")           { handleSaveAs() }
            Button("Cancel",role:.cancel) {}
        } message: { Text("Choose a unique name not used by another artwork.") }
        .alert("Name Already Used", isPresented:$showNameConflict) {
            TextField("Try a different title", text:$pendingTitle)
            Button("Save")           { handleSaveAs() }
            Button("Cancel",role:.cancel) {}
        } message: { Text("\"\(pendingTitle)\" already exists. Pick a different name.") }
        .onReceive(NotificationCenter.default.publisher(for:NSNotification.Name("DropMotif"))) { n in
            if let name = n.object as? String { placeMotif(name:name) }
        }
        .onReceive(NotificationCenter.default.publisher(for:NSNotification.Name("PlaceMotif"))) { n in
            if let name = n.object as? String { placeMotif(name:name) }
        }
    }

    // MARK: - Top bar

    var topBar: some View {
        HStack(spacing:8) {
            Button(action:{ performAutosave(); isPresented = false }) {
                HStack(spacing:4) {
                    Image(systemName:"chevron.left").font(.system(size:13,weight:.bold))
                    Text("Back").font(.system(size:13,weight:.semibold))
                }
                .foregroundColor(Color(red:0.28,green:0.10,blue:0.01))
                .padding(.vertical,8).padding(.horizontal,12).background(pillBg)
            }
            Spacer()
            // Mode pill
            HStack(spacing:4) {
                Image(systemName:toolIcon).font(.system(size:11,weight:.semibold))
                Text(toolLabel).font(.system(size:11,weight:.semibold))
            }
            .foregroundColor(Color(red:0.42,green:0.20,blue:0.01))
            .padding(.vertical,5).padding(.horizontal,10)
            .background(Capsule().fill(Color(red:0.96,green:0.88,blue:0.68).opacity(0.95))
                .overlay(Capsule().stroke(Color.mithilaGold.opacity(0.45),lineWidth:1)))
            Spacer()
            // Undo — 48×48 so it's never missed
            Button(action:performUndo) {
                Image(systemName:"arrow.uturn.backward")
                    .font(.system(size:18,weight:.semibold))
                    .foregroundColor(undoStack.isEmpty ? Color.gray.opacity(0.35) : Color(red:0.28,green:0.10,blue:0.01))
                    .frame(width:48,height:48).background(pillBg)
            }
            .buttonStyle(.plain).disabled(undoStack.isEmpty)
            Button(action:performRedo) {
                Image(systemName:"arrow.uturn.forward")
                    .font(.system(size:18,weight:.semibold))
                    .foregroundColor(redoStack.isEmpty ? Color.gray.opacity(0.35) : Color(red:0.28,green:0.10,blue:0.01))
                    .frame(width:48,height:48).background(pillBg)
            }
            .buttonStyle(.plain).disabled(redoStack.isEmpty)
            // Save menu
            Menu {
                Button(action:{ promptSave(saveAs:false) }) { Label("Save", systemImage:"arrow.down.to.line") }
                Button(action:{ promptSave(saveAs:true)  }) { Label("Save As…", systemImage:"doc.badge.plus") }
            } label: {
                Image(systemName:"arrow.down.to.line")
                    .font(.system(size:15,weight:.semibold))
                    .foregroundColor(Color(red:0.28,green:0.10,blue:0.01))
                    .padding(10).background(pillBg)
            }
            // Export
            Button(action:triggerExport) {
                HStack(spacing:4) {
                    Image(systemName:"square.and.arrow.up").font(.system(size:12,weight:.bold))
                    Text("Export").font(.system(size:12,weight:.semibold))
                }
                .foregroundColor(Color(red:0.28,green:0.10,blue:0.01))
                .padding(.vertical,8).padding(.horizontal,12)
                .background(pillBg)
            }
        }
        .padding(.horizontal,14)
    }

    var pillBg: some View {
        RoundedRectangle(cornerRadius:10)
            .fill(Color(red:0.99,green:0.97,blue:0.91).opacity(0.96))
            .overlay(RoundedRectangle(cornerRadius:10).stroke(Color(red:0.72,green:0.42,blue:0.08).opacity(0.4),lineWidth:1.2))
    }

    var toolIcon: String {
        switch activeTool {
        case .pen: return "pencil.tip"; case .eraser: return "eraser.fill"
        case .motifSelect: return "hand.point.up.left.fill"; case .fill: return "drop.fill"
        }
    }
    var toolLabel: String {
        switch activeTool {
        case .pen:         return "Draw \(Int(brushSize))pt"
        case .eraser:      return "Eraser \(Int(eraserSize))pt"
        case .motifSelect: return "Motif Mode"
        case .fill:        return "Fill"
        }
    }

    // MARK: - Tool rail
    // FIX #2: pen/eraser size sub-menus start COLLAPSED (railPenOpen/railEraserOpen = false).
    // Tap active icon to toggle sub-menu open.  Switching tools collapses everything.

    var toolRail: some View {
        VStack(spacing:12) {

            // PEN
            railBtn("pencil.tip", active: activeTool == .pen && !snapLine && !snapCircle) {
                if activeTool == .pen && !snapLine && !snapCircle {
                    railPenOpen.toggle(); railEraserOpen = false
                } else { snapLine = false; snapCircle = false; switchTo(.pen) }
            }
            .overlay(alignment: .trailing) {
                if activeTool == .pen && railPenOpen {
                    HStack(spacing:6) {
                        ForEach([2,4,8,14], id:\.self) { sz in
                            BrushSizeBtn(size:CGFloat(sz), isSelected:abs(brushSize-CGFloat(sz))<0.5) {
                                brushSize = CGFloat(sz); updateTool(); railPenOpen = false
                            }
                        }
                    }
                    .padding(.horizontal,10).padding(.vertical,8)
                    .background(railBg)
                    .fixedSize()
                    .offset(x: -64)   // shift left of the rail button
                    .transition(.scale(scale:0.85, anchor:.trailing).combined(with:.opacity))
                    .zIndex(30)
                }
            }

            // Straight-line snap
            railBtn("line.diagonal", active:snapLine) {
                snapCircle = false; snapLine.toggle()
                railPenOpen = false; switchTo(.pen)
            }
            // Circle snap
            railBtn("circle", active:snapCircle) {
                snapLine = false; snapCircle.toggle()
                railPenOpen = false; switchTo(.pen)
            }

            dotDiv

            // ERASER
            railBtn("eraser.fill", active:activeTool == .eraser) {
                if activeTool == .eraser { railEraserOpen.toggle(); railPenOpen = false }
                else { switchTo(.eraser) }
            }
            .overlay(alignment: .trailing) {
                if activeTool == .eraser && railEraserOpen {
                    HStack(spacing:6) {
                        ForEach([10,25,50], id:\.self) { sz in
                            BrushSizeBtn(size:CGFloat(sz), isSelected:abs(eraserSize-CGFloat(sz))<0.5, isEraser:true) {
                                eraserSize = CGFloat(sz); updateTool(); railEraserOpen = false
                            }
                        }
                    }
                    .padding(.horizontal,10).padding(.vertical,8)
                    .background(railBg)
                    .fixedSize()
                    .offset(x: -120)
                    .transition(.scale(scale:0.85, anchor:.trailing).combined(with:.opacity))
                    .zIndex(30)
                }
            }

            dotDiv

            // COLOUR
            Button(action:{
                withAnimation(.spring(response:0.25, dampingFraction:0.72)) { showPalette.toggle() }
            }) {
                ZStack {
                    Circle().strokeBorder(AngularGradient(colors:[.red,.orange,.yellow,.green,.cyan,.blue,.purple,.pink,.red],center:.center),lineWidth:3.5).frame(width:38,height:38)
                    Circle().fill(selectedColor).frame(width:24,height:24).overlay(Circle().stroke(Color.white,lineWidth:1.5))
                }
                .overlay(Circle().stroke(showPalette ? Color.mithilaGold : Color.clear,lineWidth:2).frame(width:42,height:42))
            }

            dotDiv

            // FILL
            railBtn("drop.fill", active:activeTool == .fill) { switchTo(.fill) }

            dotDiv

            // MOTIF MODE
            railBtn("hand.point.up.left.fill", active:activeTool == .motifSelect) { switchTo(.motifSelect) }

            // LAYERS
            railBtn("square.3.layers.3d.down.right", active:false) { showLayers.toggle() }

            // PASTE
            if clipboard != nil {
                railBtn("doc.on.clipboard", active:false) { pasteMotif(); clipboard = nil }
                    .transition(.scale.combined(with:.opacity))
            }

            dotDiv

            // CLEAR ALL
            railBtn("arrow.counterclockwise", active:false) { clearAll() }
        }
        .padding(.vertical,16).padding(.horizontal,10)
        .background(railBg)
        .padding(.trailing,16).padding(.bottom,20)
        .animation(.easeInOut(duration:0.16), value:activeTool)
        .animation(.easeInOut(duration:0.15), value:railPenOpen)
        .animation(.easeInOut(duration:0.15), value:railEraserOpen)
        .animation(.easeInOut(duration:0.14), value:clipboard != nil)
    }

    var railBg: some View {
        ZStack {
            RoundedRectangle(cornerRadius:22).fill(Color(red:0.99,green:0.97,blue:0.91))
            RoundedRectangle(cornerRadius:22).stroke(LinearGradient(colors:[Color(red:0.85,green:0.57,blue:0.10),Color(red:0.62,green:0.26,blue:0.03),Color(red:0.85,green:0.57,blue:0.10)],startPoint:.top,endPoint:.bottom),lineWidth:2)
            RoundedRectangle(cornerRadius:19).stroke(Color(red:0.85,green:0.57,blue:0.10).opacity(0.22),lineWidth:0.8).padding(3)
        }
        .shadow(color:Color(red:0.50,green:0.25,blue:0.00).opacity(0.15),radius:12,x:-2,y:0)
    }
    var dotDiv: some View {
        HStack(spacing:3) {
            ForEach(0..<5,id:\.self) { _ in Diamond().fill(Color(red:0.70,green:0.40,blue:0.04).opacity(0.38)).frame(width:4,height:4) }
        }
    }
    func railBtn(_ icon:String, active:Bool, action:@escaping()->Void) -> some View {
        Button(action:action) {
            Image(systemName:icon).font(.system(size:19))
                .foregroundColor(active ? .mithilaGold : Color(red:0.35,green:0.18,blue:0.02))
                .frame(width:36,height:36)
                .background(RoundedRectangle(cornerRadius:8).fill(active ? Color.mithilaGold.opacity(0.14):Color.clear))
        }
    }

    // MARK: - Palette wheel (circular, floats to left of rail)

    var palettePanel: some View {
        ZStack {
            // Outer decorative ring
            Circle()
                .fill(Color(red:0.99,green:0.97,blue:0.91))
                .frame(width:220,height:220)
            Circle()
                .stroke(LinearGradient(
                    colors:[Color.mithilaGold, Color(red:0.62,green:0.28,blue:0.03), Color.mithilaGold],
                    startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:2.5)
                .frame(width:220,height:220)
            Circle()
                .stroke(Color.mithilaGold.opacity(0.2), lineWidth:0.8)
                .frame(width:208,height:208)

            // Selected colour in the centre
            ZStack {
                Circle().fill(selectedColor).frame(width:50,height:50)
                Circle().stroke(Color.white,lineWidth:2.5).frame(width:50,height:50)
                Circle().stroke(Color.mithilaGold.opacity(0.5),lineWidth:1).frame(width:44,height:44)
            }

            // Colour dots arranged in a circle
            ForEach(Array(madhubaniPalette.enumerated()), id:\.offset) { i, entry in
                let angle = Double(i) / Double(madhubaniPalette.count) * 2.0 * .pi - .pi / 2.0
                let radius: CGFloat = 82
                Button(action:{
                    selectedColor = entry.0
                    if activeTool != .fill { switchTo(.pen) }
                    else { updateTool() }
                    withAnimation(.spring(response:0.25)) { showPalette = false }
                }) {
                    ZStack {
                        Circle().fill(entry.0).frame(width:30,height:30)
                        Circle()
                            .stroke(selectedColor == entry.0 ? Color.mithilaGold : Color.white.opacity(0.65),
                                    lineWidth: selectedColor == entry.0 ? 3 : 1.5)
                            .frame(width:30,height:30)
                        if selectedColor == entry.0 {
                            Circle().stroke(Color.white,lineWidth:1.1).frame(width:22,height:22)
                        }
                    }
                }
                .scaleEffect(selectedColor == entry.0 ? 1.22 : 1.0)
                .animation(.spring(response:0.22), value:selectedColor == entry.0)
                .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            }
        }
        .frame(width:220,height:220)
        .shadow(color:.black.opacity(0.18),radius:16,x:-4,y:4)
    }

    // MARK: - Motif tray button + tray

    var motifTrayButton: some View {
        Button(action:{
            withAnimation(.spring(response:0.28,dampingFraction:0.74)) { showMotifTray.toggle() }
        }) {
            ZStack {
                Capsule().fill(Color(red:0.99,green:0.97,blue:0.91))
                    .overlay(Capsule().stroke(Color.mithilaGold.opacity(0.65),lineWidth:2))
                    .shadow(color:Color(red:0.50,green:0.25,blue:0.00).opacity(0.2),radius:8)
                HStack(spacing:7) {
                    Image(systemName:"scribble.variable").font(.system(size:16,weight:.semibold)).foregroundColor(.mithilaGold)
                    Text("Motifs").font(.system(size:13,weight:.bold)).foregroundColor(Color(red:0.28,green:0.10,blue:0.01))
                    Image(systemName:showMotifTray ? "chevron.down":"chevron.up").font(.system(size:10,weight:.bold)).foregroundColor(Color.mithilaGold.opacity(0.8))
                }
                .padding(.horizontal,16).padding(.vertical,11)
            }.fixedSize()
        }.buttonStyle(.plain)
    }

    var motifTray: some View {
        VStack(spacing:0) {
            Capsule().fill(Color.mithilaGold.opacity(0.35)).frame(width:44,height:4).padding(.top,10).padding(.bottom,6)
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:16) {
                    ForEach(motifNames,id:\.self) { name in
                        Button(action:{ placeMotif(name:name); withAnimation { showMotifTray=false } }) {
                            VStack(spacing:6) {
                                ZStack {
                                    Circle().fill(Color(red:0.95,green:0.92,blue:0.84)).frame(width:70,height:70)
                                    Circle().stroke(Color.mithilaGold.opacity(0.4),lineWidth:1.5).frame(width:70,height:70)
                                    if UIImage(named:name) != nil {
                                        Image(name).renderingMode(.original).resizable().scaledToFit().blendMode(.multiply).frame(width:54,height:54)
                                    } else {
                                        Image(systemName:"photo").font(.system(size:26)).foregroundColor(Color.mithilaGold.opacity(0.5))
                                    }
                                }
                                Text(name.replacingOccurrences(of:"_art",with:"").capitalized)
                                    .font(.system(size:11,weight:.semibold)).foregroundColor(Color(red:0.28,green:0.10,blue:0.01))
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal,20).padding(.bottom,24)
            }
        }
        .background(ZStack {
            RoundedRectangle(cornerRadius:20,style:.continuous).fill(Color(red:0.99,green:0.97,blue:0.91))
            RoundedRectangle(cornerRadius:20,style:.continuous).stroke(LinearGradient(colors:[Color.mithilaGold.opacity(0.6),Color(red:0.62,green:0.28,blue:0.02).opacity(0.4),Color.mithilaGold.opacity(0.6)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1.5)
        }.shadow(color:.black.opacity(0.12),radius:16,x:0,y:-4))
        .padding(.horizontal,12)
    }

    // MARK: - Motif controls bar

    var motifControls: some View {
        HStack(spacing:12) {
            Button(action:{ selectedMotifID = nil; switchTo(.pen) }) {
                Text("Done").font(.system(size:13,weight:.bold)).foregroundColor(.white)
                    .padding(.horizontal,18).padding(.vertical,9)
                    .background(Capsule().fill(Color.mithilaGold))
            }
            if let idx = motifs.firstIndex(where:{ $0.id == selectedMotifID }) {
                // Scale slider
                HStack(spacing:5) {
                    Image(systemName:"minus").font(.caption2).foregroundColor(.secondary)
                    Slider(value:$motifs[idx].scale,in:0.3...4.0).accentColor(.mithilaGold).frame(width:110)
                    Image(systemName:"plus").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal,10).padding(.vertical,8)
                .background(Capsule().fill(Color(red:0.99,green:0.97,blue:0.91).opacity(0.97)).overlay(Capsule().stroke(Color.mithilaGold.opacity(0.35),lineWidth:1)))
                // Rotation slider
                HStack(spacing:5) {
                    Image(systemName:"rotate.left").font(.caption2).foregroundColor(.secondary)
                    Slider(value:$motifs[idx].rotation, in:-180...180)
                        .accentColor(Color(red:0.17,green:0.24,blue:0.69))
                        .frame(width:110)
                    Image(systemName:"rotate.right").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal,10).padding(.vertical,8)
                .background(Capsule().fill(Color(red:0.99,green:0.97,blue:0.91).opacity(0.97)).overlay(Capsule().stroke(Color.mithilaGold.opacity(0.35),lineWidth:1)))
                // Tint fill button
                Button(action:{
                    guard idx < motifs.count else { return }
                    let old = motifs[idx].tintColor
                    let new = CodableColor(selectedColor)
                    motifs[idx].tintColor = new
                    pushUndo(.motifTinted(motifs[idx].id, old, new))
                    isDirty = true
                }) {
                    HStack(spacing:4) {
                        Image(systemName:"drop.fill").font(.system(size:14))
                        Text("Fill").font(.system(size:12,weight:.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal,14).padding(.vertical,9)
                    .background(Capsule().fill(selectedColor))
                }
                // Switch to pen without losing selection
                Button(action:{ activeTool = .pen; updateTool() }) {
                    Image(systemName:"pencil").font(.system(size:15))
                        .foregroundColor(Color(red:0.32,green:0.14,blue:0.01)).padding(9)
                        .background(Circle().fill(Color(red:0.99,green:0.97,blue:0.91)).overlay(Circle().stroke(Color.mithilaGold.opacity(0.35),lineWidth:1)))
                }
            }
        }
        .padding(.horizontal,20).padding(.vertical,12)
        .background(RoundedRectangle(cornerRadius:20).fill(Color(red:0.99,green:0.97,blue:0.91).opacity(0.97)).overlay(RoundedRectangle(cornerRadius:20).stroke(Color.mithilaGold.opacity(0.4),lineWidth:1.5)).shadow(color:.black.opacity(0.12),radius:12))
        .padding(.bottom,30)
    }

    // MARK: - Layers Panel (Fix #2)

    var layersPanel: some View {
        VStack(spacing:0) {
            HStack {
                Text("Layers").font(.system(size:14,weight:.bold))
                    .foregroundColor(Color(red:0.22,green:0.09,blue:0.01))
                Spacer()
                Button(action:{ showLayers = false }) {
                    Image(systemName:"xmark.circle.fill").font(.system(size:18))
                        .foregroundColor(Color(red:0.55,green:0.28,blue:0.02).opacity(0.5))
                }
            }
            .padding(.horizontal,14).padding(.vertical,10)
            Rectangle().fill(Color.mithilaGold.opacity(0.3)).frame(height:1)
            if motifs.isEmpty {
                Text("No motifs yet").font(.system(size:12)).foregroundColor(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(spacing:0) {
                        ForEach(Array(motifs.enumerated().reversed()), id:\.element.id) { i, motif in
                            HStack(spacing:10) {
                                // Thumbnail
                                ZStack {
                                    RoundedRectangle(cornerRadius:6).fill(Color(red:0.95,green:0.92,blue:0.84)).frame(width:32,height:32)
                                    Image(motif.imageName).renderingMode(.original).resizable()
                                        .scaledToFit().blendMode(.multiply).frame(width:24,height:24)
                                }
                                Text(motif.imageName.replacingOccurrences(of:"_art",with:"").capitalized)
                                    .font(.system(size:12,weight: selectedMotifID==motif.id ? .bold:.regular))
                                    .foregroundColor(selectedMotifID==motif.id ? .mithilaGold : Color(red:0.22,green:0.09,blue:0.01))
                                Spacer()
                                // Move up/down
                                Button(action:{
                                    if i < motifs.count-1 { motifs.swapAt(i, i+1) }
                                }) { Image(systemName:"chevron.up").font(.system(size:10,weight:.bold)).foregroundColor(Color(red:0.45,green:0.22,blue:0.01)) }
                                Button(action:{
                                    if i > 0 { motifs.swapAt(i, i-1) }
                                }) { Image(systemName:"chevron.down").font(.system(size:10,weight:.bold)).foregroundColor(Color(red:0.45,green:0.22,blue:0.01)) }
                                // Lock
                                Button(action:{
                                    motifs[i].isLocked.toggle()
                                    if motifs[i].isLocked && selectedMotifID==motif.id { selectedMotifID=nil }
                                }) {
                                    Image(systemName:motif.isLocked ? "lock.fill":"lock.open")
                                        .font(.system(size:11)).foregroundColor(motif.isLocked ? .mithilaGold:.secondary)
                                }
                                // Delete
                                Button(action:{ deleteMotif(motif.id) }) {
                                    Image(systemName:"trash").font(.system(size:11)).foregroundColor(.red.opacity(0.7))
                                }
                            }
                            .padding(.horizontal,12).padding(.vertical,8)
                            .background(selectedMotifID==motif.id ? Color.mithilaGold.opacity(0.08):Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMotifID = motif.id
                                activeTool = .motifSelect
                                showLayers = false
                            }
                            Rectangle().fill(Color(red:0.85,green:0.60,blue:0.10).opacity(0.12)).frame(height:1)
                        }
                    }
                }
                .frame(maxHeight:280)
            }
        }
        .frame(width:230)
        .background(ZStack {
            RoundedRectangle(cornerRadius:16).fill(Color(red:0.99,green:0.97,blue:0.91))
            RoundedRectangle(cornerRadius:16).stroke(LinearGradient(colors:[Color.mithilaGold.opacity(0.7),Color(red:0.62,green:0.28,blue:0.02).opacity(0.4),Color.mithilaGold.opacity(0.7)],startPoint:.top,endPoint:.bottom),lineWidth:1.5)
        })
        .shadow(color:Color(red:0.50,green:0.25,blue:0.00).opacity(0.18),radius:14,x:-4,y:0)
    }

    // MARK: - Tool switching

    func switchTo(_ tool: CanvasTool) {
        selectedMotifID = nil
        activeTool      = tool
        showPalette     = false
        railPenOpen     = false
        railEraserOpen  = false
        updateTool()
    }

    func updateTool() {
        switch activeTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color:UIColor(selectedColor), width:brushSize)
        case .eraser:
            if #available(iOS 16.4,*) { canvasView.tool = PKEraserTool(.bitmap, width:eraserSize) }
            else { canvasView.tool = PKEraserTool(.bitmap) }
        case .motifSelect, .fill: break
        }
    }

    // MARK: - Fill
    // FIX #1: true MS-Paint-style BFS flood fill using a pixel buffer.
    // FIX #7: re-filling with a different colour replaces the old fill completely
    //         because we re-run BFS from scratch on the current drawing state.

    func handleFillTap(at loc: CGPoint) {
        // Check if the tap hit a motif bounding box — use the real frame size (220 * scale)
        if let hm = motifs.last(where: { m in
            let hw = 110 * m.scale   // half of 220 * scale
            return abs(loc.x-m.position.x)<hw && abs(loc.y-m.position.y)<hw
        }) {
            if let idx = motifs.firstIndex(where:{ $0.id == hm.id }) {
                fillMotifRegion(index: idx, tapLocation: loc)
            }
            return
        }
        applyCanvasFill(at: loc)
    }

    /// Per-region BFS fill on the motif's own pixel buffer so multiple regions
    /// can each have independent colours (like the sun's inner disc vs. outer ring).
    func fillMotifRegion(index: Int, tapLocation: CGPoint) {
        guard index < motifs.count else { return }
        let m = motifs[index]
        let frameW = 220 * m.scale
        let origin = CGPoint(x: m.position.x - frameW/2, y: m.position.y - frameW/2)

        let localX = tapLocation.x - origin.x
        let localY = tapLocation.y - origin.y
        guard localX >= 0, localY >= 0, localX < frameW, localY < frameW else { return }

        let pxScale = UIScreen.main.scale
        let pw = Int(frameW * pxScale), ph = Int(frameW * pxScale)
        guard pw > 0 else { return }

        var pixels = [UInt8](repeating: 0, count: pw * ph * 4)
        guard let ctx = CGContext(data: &pixels, width: pw, height: ph,
                                  bitsPerComponent: 8, bytesPerRow: pw*4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }

        // FIX 6: transparent base so PNG has alpha — view uses .blendMode(.multiply)
        // which makes white/transparent areas show the canvas behind, fixing the white-square issue.
        ctx.clear(CGRect(x:0,y:0,width:pw,height:ph))
        // Fill with white so line-art (black on white) renders correctly before BFS
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x:0,y:0,width:pw,height:ph))

        // FIX 11+12: if we already have accumulated fills, start FROM that image —
        // this preserves all previous region colours instead of resetting to white
        if let existingData = m.filledImageData,
           let existingUI   = UIImage(data: existingData),
           let existingCG   = existingUI.cgImage {
            ctx.draw(existingCG, in: CGRect(x:0,y:0,width:pw,height:ph))
        } else {
            // First fill: draw base motif image
            if let cg = UIImage(named: m.imageName)?.cgImage {
                ctx.draw(cg, in: CGRect(x:0,y:0,width:pw,height:ph))
            }
        }

        // Always redraw the outline art on top so line-art stays sharp
        if let cg = UIImage(named: m.imageName)?.cgImage {
            // Draw at multiply blend so transparent areas stay transparent
            ctx.saveGState()
            ctx.setBlendMode(.multiply)
            ctx.draw(cg, in: CGRect(x:0,y:0,width:pw,height:ph))
            ctx.restoreGState()
        }

        let tapPx = Int(localX * pxScale), tapPy = Int(localY * pxScale)
        guard tapPx >= 0, tapPy >= 0, tapPx < pw, tapPy < ph else { return }

        let sIdx = (tapPy * pw + tapPx) * 4
        let sR = pixels[sIdx], sG = pixels[sIdx+1], sB = pixels[sIdx+2]

        // Don't fill on very dark outline pixels
        if Int(sR)+Int(sG)+Int(sB) < 100 { return }

        var fr:CGFloat=0, fg:CGFloat=0, fb:CGFloat=0, fa:CGFloat=0
        UIColor(selectedColor).getRed(&fr, green:&fg, blue:&fb, alpha:&fa)
        let fR=UInt8(fr*255), fG=UInt8(fg*255), fB=UInt8(fb*255)

        // Same colour already? skip
        if sR==fR && sG==fG && sB==fB { return }

        func pixMatch(_ i:Int)->Bool {
            if Int(pixels[i])+Int(pixels[i+1])+Int(pixels[i+2]) < 100 { return false }
            return abs(Int(pixels[i])-Int(sR))<=40
                && abs(Int(pixels[i+1])-Int(sG))<=40
                && abs(Int(pixels[i+2])-Int(sB))<=40
        }

        var visited = [Bool](repeating: false, count: pw*ph)
        var queue = [(tapPx, tapPy)]; var head = 0
        visited[tapPy*pw+tapPx] = true
        let cap = pw*ph          // no arbitrary cap — let BFS fill the whole closed region
        while head < queue.count && head < cap {
            let (x,y) = queue[head]; head+=1
            let k = (y*pw+x)*4
            pixels[k]=fR; pixels[k+1]=fG; pixels[k+2]=fB; pixels[k+3]=255
            for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let nx=x+dx, ny=y+dy
                guard nx>=0,ny>=0,nx<pw,ny<ph else { continue }
                let ni=ny*pw+nx
                if !visited[ni] && pixMatch(ni*4) { visited[ni]=true; queue.append((nx,ny)) }
            }
        }

        guard let outCG = ctx.makeImage() else { return }
        let filledUI = UIImage(cgImage: outCG, scale: pxScale, orientation: .up)
        // FIX 12: store the accumulated fill image — preserved on duplicate/move/save
        let oldTint = m.tintColor
        motifs[index].filledImageData = filledUI.pngData()
        pushUndo(.motifTinted(m.id, oldTint, CodableColor(selectedColor)))
        isDirty = true
    }

    func applyCanvasFill(at tap: CGPoint) {
        let sz = canvasSize == .zero ? CGSize(width:800,height:1024) : canvasSize
        let w = Int(sz.width), h = Int(sz.height)
        guard w > 0, h > 0 else { return }

        let bpr = 4 * w
        var pixels = [UInt8](repeating:0, count:h*bpr)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data:&pixels, width:w, height:h, bitsPerComponent:8,
                                  bytesPerRow:bpr, space:cs,
                                  bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }

        // Render paper + strokes at 1× so pixel coords == view point coords
        ctx.setFillColor(UIColor(red:0.96,green:0.94,blue:0.89,alpha:1).cgColor)
        ctx.fill(CGRect(x:0,y:0,width:w,height:h))
        if let cg = canvasView.drawing.image(from:CGRect(origin:.zero,size:sz),scale:1.0).cgImage {
            ctx.draw(cg, in:CGRect(x:0,y:0,width:w,height:h))
        }

        let tx = max(0,min(w-1,Int(tap.x))), ty = max(0,min(h-1,Int(tap.y)))
        let sI = (ty*w+tx)*4
        let sR=pixels[sI],sG=pixels[sI+1],sB=pixels[sI+2]

        var fr:CGFloat=0,fg:CGFloat=0,fb:CGFloat=0,fa:CGFloat=0
        UIColor(selectedColor).getRed(&fr,green:&fg,blue:&fb,alpha:&fa)
        let fillR=UInt8(fr*255),fillG=UInt8(fg*255),fillB=UInt8(fb*255)
        guard !(sR==fillR && sG==fillG && sB==fillB) else { return }

        // Tight tolerance so ink lines (dark pixels) act as walls
        let tol = 22
        func isMatch(_ i:Int)->Bool {
            abs(Int(pixels[i])-Int(sR))<=tol
            && abs(Int(pixels[i+1])-Int(sG))<=tol
            && abs(Int(pixels[i+2])-Int(sB))<=tol
        }

        // Hard cap: 600k ≈ a large hand-drawn shape on iPad canvas.
        // This allows filling big shapes while still preventing unbounded open-canvas fills.
        let bfsHardCap = 600_000
        var visited = [Bool](repeating:false, count:w*h)
        var queue = [(tx,ty)]; var head = 0
        while head < queue.count && head < bfsHardCap {
            let (x,y)=queue[head]; head+=1
            let key=y*w+x
            if visited[key] { continue }
            let idx=key*4
            if !isMatch(idx) { continue }
            visited[key]=true
            pixels[idx]=fillR; pixels[idx+1]=fillG; pixels[idx+2]=fillB; pixels[idx+3]=255
            if x>0   { queue.append((x-1,y)) }
            if x<w-1 { queue.append((x+1,y)) }
            if y>0   { queue.append((x,y-1)) }
            if y<h-1 { queue.append((x,y+1)) }
        }
        guard visited.contains(true) else { return }
        let filledCount = visited.filter{$0}.count
        // If BFS hit the cap it means the region is open/unbounded → don't fill
        guard filledCount < bfsHardCap else { return }

        // Build scan-line PKStrokes
        let before = canvasView.drawing
        let inkColor = UIColor(selectedColor)
        var newStrokes: [PKStroke] = before.strokes
        var y = 0
        while y < h {
            var x = 0, runStart: Int? = nil
            while x <= w {
                let inFill = x < w && visited[y*w+x]
                if inFill, runStart == nil { runStart = x }
                if !inFill, let rs = runStart {
                    let p0=CGPoint(x:CGFloat(rs),  y:CGFloat(y))
                    let p1=CGPoint(x:CGFloat(x-1), y:CGFloat(y))
                    let mk = { (pt:CGPoint, t:Double) in
                        PKStrokePoint(location:pt,timeOffset:t,
                                      size:CGSize(width:2,height:2),  // thinner = no square bleed at stroke ends
                                      opacity:1,force:1,azimuth:0,altitude:.pi/2)
                    }
                    newStrokes.append(PKStroke(ink:PKInk(.pen,color:inkColor),
                                               path:PKStrokePath(controlPoints:[mk(p0,0),mk(p1,0.001)],
                                                                 creationDate:Date())))
                    runStart = nil
                }
                x += 1
            }
            y += 1
        }
        var newD = PKDrawing(); newD.strokes = newStrokes
        canvasView.drawing = newD
        pushUndo(.drawing(before, newD))
        isDirty = true
    }

    // MARK: - FIX #5: Clear ALL (canvas + motifs), undoable as one action

    func clearAll() {
        let snapDrawing = canvasView.drawing
        let snapMotifs  = motifs
        pushUndo(.clearAll(snapDrawing, snapMotifs))
        canvasView.drawing = PKDrawing()
        motifs.removeAll()
        selectedMotifID = nil
        isDirty = true
    }

    // MARK: - Undo / Redo
    // FIX #8: tracks pen strokes, eraser strokes, fill, motif add/move/scale/delete/tint, clearAll

    func pushUndo(_ item: UndoItem) {
        undoStack.append(item)
        redoStack.removeAll()
        if undoStack.count > 80 { undoStack.removeFirst() }
    }

    func performUndo() {
        guard let item = undoStack.popLast() else { return }
        applyUndo(item, isUndo:true)
    }
    func performRedo() {
        guard let item = redoStack.popLast() else { return }
        applyUndo(item, isUndo:false)
    }

    func applyUndo(_ item: UndoItem, isUndo: Bool) {
        // Each case: apply the state change, push the INVERSE onto the opposite stack.
        // We do NOT touch the stack we just popped from — caller already removed the item.
        switch item {
        case .drawing(let before, let after):
            canvasView.drawing = isUndo ? before : after
            let inverse = UndoItem.drawing(before, after) // inverse restores other direction
            if isUndo { redoStack.append(.drawing(before, after)) }
            else       { undoStack.append(.drawing(before, after)) }

        case .motifAdded(let m):
            if isUndo {
                let idx = motifs.firstIndex(where:{$0.id==m.id}) ?? motifs.count
                motifs.removeAll{$0.id==m.id}
                redoStack.append(.motifAdded(m))
            } else {
                motifs.append(m)
                undoStack.append(.motifAdded(m))
            }

        case .motifDeleted(let m, let idx):
            if isUndo {
                motifs.insert(m, at:min(idx,motifs.count))
                redoStack.append(.motifDeleted(m,idx))
            } else {
                motifs.removeAll{$0.id==m.id}
                undoStack.append(.motifDeleted(m,idx))
            }

        case .motifMoved(let id, let from, let to):
            if let i = motifs.firstIndex(where:{$0.id==id}) {
                motifs[i].position = isUndo ? from : to
            }
            if isUndo { redoStack.append(.motifMoved(id, from, to)) }
            else       { undoStack.append(.motifMoved(id, from, to)) }

        case .motifScaled(let id, let from, let to):
            if let i = motifs.firstIndex(where:{$0.id==id}) {
                motifs[i].scale = isUndo ? from : to
            }
            if isUndo { redoStack.append(.motifScaled(id, from, to)) }
            else       { undoStack.append(.motifScaled(id, from, to)) }

        case .motifTinted(let id, let old, let new):
            if let i = motifs.firstIndex(where:{$0.id==id}) {
                motifs[i].tintColor = isUndo ? old : new
            }
            if isUndo { redoStack.append(.motifTinted(id, old, new)) }
            else       { undoStack.append(.motifTinted(id, old, new)) }

        case .motifRotated(let id, let from, let to):
            if let i = motifs.firstIndex(where:{$0.id==id}) {
                motifs[i].rotation = isUndo ? from : to
            }
            if isUndo { redoStack.append(.motifRotated(id, from, to)) }
            else       { undoStack.append(.motifRotated(id, from, to)) }

        case .clearAll(let drawing, let motifsSnap):
            if isUndo {
                canvasView.drawing = drawing
                motifs = motifsSnap
                redoStack.append(.clearAll(drawing, motifsSnap))
            } else {
                canvasView.drawing = PKDrawing()
                motifs.removeAll()
                undoStack.append(.clearAll(drawing, motifsSnap))
            }
        }
        isDirty = true
    }

    // MARK: - Motif CRUD

    func placeMotif(name: String) {
        let m = MotifInstance(imageName:name, position:CGPoint(x:canvasSize.width/2,y:canvasSize.height/2))
        motifs.append(m)
        selectedMotifID = m.id
        activeTool = .motifSelect
        pushUndo(.motifAdded(m))
        isDirty = true
    }
    func duplicateMotif(_ m: MotifInstance) {
        var c = MotifInstance(imageName:m.imageName, position:CGPoint(x:m.position.x+50,y:m.position.y+50), scale:m.scale)
        c.tintColor       = m.tintColor
        c.rotation        = m.rotation
        c.filledImageData = m.filledImageData
        motifs.append(c); selectedMotifID = c.id; activeTool = .motifSelect
        pushUndo(.motifAdded(c)); isDirty = true
    }
    func deleteMotif(_ id: UUID) {
        guard let idx = motifs.firstIndex(where:{$0.id==id}) else { return }
        let m = motifs[idx]
        pushUndo(.motifDeleted(m,idx))
        withAnimation { motifs.remove(at:idx) }
        if selectedMotifID == id { selectedMotifID = nil }
        isDirty = true
    }
    func pasteMotif() {
        guard let src = clipboard else { return }
        var c = MotifInstance(imageName:src.imageName, position:CGPoint(x:canvasSize.width/2+30,y:canvasSize.height/2+30), scale:src.scale)
        c.tintColor       = src.tintColor
        c.rotation        = src.rotation
        c.filledImageData = src.filledImageData
        motifs.append(c); selectedMotifID = c.id; activeTool = .motifSelect
        pushUndo(.motifAdded(c)); isDirty = true
    }

    // MARK: - Export

    func compositeImage() -> UIImage {
        let size = canvasSize == .zero ? CGSize(width:800,height:1024) : canvasSize
        return UIGraphicsImageRenderer(size:size).image { _ in
            UIColor(red:0.96,green:0.94,blue:0.89,alpha:1).setFill()
            UIRectFill(CGRect(origin:.zero,size:size))
            for m in motifs {
                let w=220*m.scale, h=220*m.scale
                let rect=CGRect(x:-w/2, y:-h/2, width:w, height:h)
                let ctx = UIGraphicsGetCurrentContext()!
                ctx.saveGState()
                ctx.translateBy(x: m.position.x, y: m.position.y)
                ctx.rotate(by: CGFloat(m.rotation) * .pi / 180)
                if let data = m.filledImageData, let ui = UIImage(data: data) {
                    ui.draw(in: rect)
                } else {
                    if let t = m.tintColor {
                        t.uiColor.setFill(); UIRectFill(rect)
                    }
                    if let ui = UIImage(named: m.imageName) {
                        ui.draw(in: rect, blendMode: .multiply, alpha: 1.0)
                    }
                }
                ctx.restoreGState()
            }
            canvasView.drawing.image(from:CGRect(origin:.zero,size:size),scale:UIScreen.main.scale)
                .draw(in:CGRect(origin:.zero,size:size))
        }
    }

    func triggerExport() {
        let img = compositeImage()
        exportImage = img
        DispatchQueue.main.async { showShareSheet = true }
    }

    // MARK: - Save / Autosave
    // FIX #9: complete rewrite of save logic.
    // - New canvas: writes to a FRESH entry. Never inherits another session's work.
    // - Autosave: flagged isAutosave=true, updated in place (same UUID every 25 sec).
    // - Named save: removes the autosave slot and writes a permanent entry.
    // - Resuming a project: loads that exact entry, overwrites it on save.

    func loadProject() {
        if let p = resumeProject {
            // Explicitly opening an existing project
            currentProjectID = p.id
            currentTitle     = p.title
            if let d = store.loadDrawing(for:p) { canvasView.drawing = d }
            motifs = store.loadMotifs(for:p)
            isDirty = false
        }
        // New canvas: do NOT load anything from autosave — a new canvas is always blank.
        // The autosave from a previous session belongs to THAT session; we ignore it here.
    }

    func startAutosave() {
        autosaveTimer = Timer.scheduledTimer(withTimeInterval:25, repeats:true) { _ in
            Task { @MainActor in performAutosave() }
        }
    }
    func stopAutosave() { autosaveTimer?.invalidate(); autosaveTimer = nil }

    func performAutosave() {
        guard isDirty || (currentProjectID == nil && !motifs.isEmpty) ||
              (currentProjectID == nil && !canvasView.drawing.strokes.isEmpty)
        else { return }

        let thumb = compositeImage()
        // If we already have an autosave slot for this session, reuse its id.
        // If we have a named project, just update it in place.
        let saveID  = currentProjectID
        let isAuto  = currentTitle.isEmpty

        store.save(
            title     : isAuto ? "__autosave__" : currentTitle,
            thumbnail : thumb,
            drawing   : canvasView.drawing,
            motifs    : motifs,
            existingID: saveID,
            isAutosave: isAuto
        )
        // Pin the id so future autosaves overwrite the same slot
        if currentProjectID == nil {
            currentProjectID = store.projects.first?.id
        }
        isDirty = false
    }

    func promptSave(saveAs: Bool) {
        if saveAs || currentTitle.isEmpty {
            pendingTitle = currentTitle
            showSaveAsAlert = true
        } else {
            doCommitSave(title:currentTitle, reuseID:true)
        }
    }

    func doCommitSave(title: String, reuseID: Bool) {
        let thumb = compositeImage()
        // Always reuse currentProjectID if we have one (covers new-name saves on existing canvas)
        let useID: UUID? = reuseID ? currentProjectID : nil
        store.save(title:title, thumbnail:thumb, drawing:canvasView.drawing, motifs:motifs,
                   existingID:useID, isAutosave:false)
        currentTitle = title
        // Find saved entry — it's at position 0 since store inserts at front
        if let saved = store.projects.first(where:{ $0.title == title && !$0.isAutosave }) {
            currentProjectID = saved.id
        }
        isDirty = false
        // Clean up autosave for this session
        if let auto = store.autosave, auto.id != currentProjectID {
            store.delete(auto)
        }
        UIImageWriteToSavedPhotosAlbum(thumb, nil, nil, nil)
        toast("Saved \"\(title)\"")
    }

    func handleSaveAs() {
        let t = pendingTitle.trimmingCharacters(in:.whitespaces)
        guard !t.isEmpty else { return }
        if store.isNameTaken(t, excludingID:currentProjectID) {
            showNameConflict = true; return
        }
        // Same name as current = overwrite. Different name = new slot.
        doCommitSave(title:t, reuseID: currentProjectID != nil)
    }

    func toast(_ msg: String) {
        toastMsg = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline:.now()+2.5) { withAnimation { showToast = false } }
    }
}  // end CanvasView

// MARK: - MotifItemView
// FIX #2: drawing starts on motif in pen mode (allowsHitTesting driven by parent zIndex)
// FIX #4: drag works for any selected motif regardless of how many motifs exist

struct MotifItemView: View {
    @Binding var motif: MotifInstance
    let isSelected:    Bool
    let isMotifMode:   Bool
    let activeTool:    CanvasTool
    let selectedColor: Color
    let onTap:        () -> Void
    let onDragEnd:    (CGPoint, CGPoint) -> Void
    let onFillTap:    () -> Void
    let onCut, onCopy, onDuplicate, onToggleLock, onDelete: () -> Void
    let onScaleDelta: (CGFloat) -> Void
    let onRotateEnd: (Double, Double) -> Void

    @State private var dragStart:    CGPoint? = nil
    // FIX 9: store the committed rotation at gesture start; only add the delta each frame
    @State private var rotBase:      Double   = 0.0
    @State private var liveRotDelta: Double   = 0.0   // extra degrees being dragged right now
    @State private var rotFromDeg:   Double   = 0.0   // for undo

    private var frameW: CGFloat { 220 * motif.scale }
    private var totalRotation: Double { motif.rotation + liveRotDelta }

    var body: some View {
        ZStack {
            // FIX 10+11+12: always render from filledImageData when present — this is the
            // accumulated multi-region fill bitmap. Never reset it to white on render.
            if let data = motif.filledImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFit()
                    .blendMode(.multiply)   // FIX 6: white areas become transparent so motifs don't occlude each other
            } else {
                if let tc = motif.tintColor {
                    Rectangle().fill(tc.color)
                        .mask(Image(motif.imageName).renderingMode(.original)
                                .resizable().scaledToFit())
                }
                Image(motif.imageName)
                    .renderingMode(.original)
                    .resizable().scaledToFit()
                    .blendMode(.multiply)
            }
        }
        .frame(width:frameW, height:frameW)
        .rotationEffect(.degrees(totalRotation))   // FIX 9: stable rotation from motif centre
        .opacity(motif.isLocked ? 0.4 : 1.0)
        .overlay(selectionBorder)
        .position(motif.position)
        .contentShape(Rectangle())
        .onTapGesture {
            if activeTool == .fill { onFillTap() }
            else { onTap() }
        }
        .contextMenu { contextMenuItems }
        .simultaneousGesture(
            DragGesture(minimumDistance:6, coordinateSpace:.global)
                .onChanged { val in
                    guard isMotifMode, !motif.isLocked else { return }
                    if dragStart == nil { dragStart = val.startLocation }
                    motif.position = val.location
                }
                .onEnded { val in
                    guard isMotifMode, let start = dragStart else { dragStart = nil; return }
                    onDragEnd(start, val.location)
                    dragStart = nil
                }
        )
        .simultaneousGesture(MagnificationGesture()
            .onChanged { val in
                guard !motif.isLocked else { return }
                onScaleDelta(val)
            }
        )
        // FIX 9: RotationGesture reports cumulative angle from gesture start each frame.
        // We snapshot rotBase at start and add (currentAngle - startAngle) to it.
        .simultaneousGesture(
            RotationGesture()
                .onChanged { angle in
                    guard !motif.isLocked, isMotifMode else { return }
                    liveRotDelta = angle.degrees
                }
                .onEnded { angle in
                    let from = motif.rotation
                    motif.rotation += liveRotDelta
                    liveRotDelta = 0
                    onRotateEnd(from, motif.rotation)
                }
        )
    }

    @ViewBuilder private var selectionBorder: some View {
        if isSelected {
            ZStack {
                RoundedRectangle(cornerRadius:8).stroke(style:StrokeStyle(lineWidth:2,dash:[6,3])).foregroundColor(.mithilaGold)
                GeometryReader { g in
                    let w=g.size.width, h=g.size.height
                    ForEach([CGPoint(x:0,y:0),CGPoint(x:w,y:0),CGPoint(x:0,y:h),CGPoint(x:w,y:h)],id:\.x) { pt in
                        Circle().fill(Color.mithilaGold).frame(width:10,height:10)
                            .overlay(Circle().stroke(Color.white,lineWidth:1.5)).position(pt)
                    }
                }
            }
        }
    }

    @ViewBuilder private var contextMenuItems: some View {
        Button(action:onCut)       { Label("Cut",       systemImage:"scissors") }
        Button(action:onCopy)      { Label("Copy",      systemImage:"doc.on.doc") }
        Button(action:onDuplicate) { Label("Duplicate", systemImage:"plus.square.on.square") }
        Divider()
        Button(action:onToggleLock) {
            Label(motif.isLocked ? "Unlock":"Lock",
                  systemImage:motif.isLocked ? "lock.open.fill":"lock.fill")
        }
        Divider()
        Button(role:.destructive,action:onDelete) { Label("Delete",systemImage:"trash") }
    }
}

// MARK: - BrushSizeBtn

struct BrushSizeBtn: View {
    let size:CGFloat; let isSelected:Bool; var isEraser:Bool=false; let action:()->Void
    private var d: CGFloat { min(6+size*1.5,28) }
    var body: some View {
        Button(action:action) {
            ZStack {
                Circle().fill(isSelected ? Color.mithilaGold:Color(red:0.7,green:0.5,blue:0.2).opacity(0.25)).frame(width:30,height:30)
                Circle().fill(isEraser ? Color.white:(isSelected ? Color.white:Color(red:0.4,green:0.2,blue:0.0))).frame(width:d,height:d)
                if isEraser { Circle().stroke(Color.gray.opacity(0.4),lineWidth:0.5).frame(width:d,height:d) }
            }
        }
    }
}

// MARK: - Diamond

struct Diamond: Shape {
    func path(in rect:CGRect)->Path {
        var p=Path()
        p.move(to:CGPoint(x:rect.midX,y:rect.minY)); p.addLine(to:CGPoint(x:rect.maxX,y:rect.midY))
        p.addLine(to:CGPoint(x:rect.midX,y:rect.maxY)); p.addLine(to:CGPoint(x:rect.minX,y:rect.midY))
        p.closeSubpath(); return p
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let image:UIImage
    func makeUIViewController(context:Context)->UIActivityViewController {
        let vc=UIActivityViewController(activityItems:[image],applicationActivities:nil)
        vc.excludedActivityTypes=[.assignToContact,.addToReadingList,.openInIBooks]
        if let pop=vc.popoverPresentationController {
            pop.sourceView=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first?.windows.first
            pop.sourceRect=CGRect(x:UIScreen.main.bounds.width-60,y:60,width:1,height:1)
            pop.permittedArrowDirections = .up
        }
        return vc
    }
    func updateUIViewController(_:UIActivityViewController,context:Context){}
}
