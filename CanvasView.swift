import SwiftUI
import PencilKit

// MARK: - New Motif Structure
struct MotifInstance: Identifiable {
    let id = UUID()
    var imageName: String
    var position: CGPoint
    var scale: CGFloat = 1.0
    var isLocked: Bool = false
}

struct CanvasView: View {
    @Binding var isPresented: Bool
    
    // MARK: - Canvas State
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: Color = .lampBlack
    @State private var eraserSize: CGFloat = 30.0
    @State private var isEraserActive = false
    @State private var showUI = true
    @State private var showMotifSheet = false
    
    // MARK: - Multi-Motif State
    @State private var motifs: [MotifInstance] = []
    @State private var selectedMotifID: UUID? = nil
    @State private var showMotifControls = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // LAYER 1: Background
            Color.handmadePaper
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showUI.toggle()
                        selectedMotifID = nil
                        showMotifControls = false
                    }
                }
                .zIndex(0)
            
            // LAYER 1.5: CUSTOM SVG MOTIF LAYER
            ZStack {
                ForEach($motifs) { $motif in
                    // Find this inside your ZStack in CanvasView.swift
                    // Update the Image inside the ForEach in CanvasView.swift
                    // Inside the motifs ForEach in CanvasView.swift
                    // Inside the motifs ForEach in CanvasView.swift
                    Image(motif.imageName)
                        .resizable()
                        .renderingMode(.original) // FIX: Keeps your original black ink
                        .scaledToFit()
                        .frame(width: 250 * motif.scale, height: 250 * motif.scale)
                        .opacity(motif.isLocked ? 0.2 : 0.6)
                        .position(motif.position)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(action: { motif.isLocked.toggle() }) {
                                Label(motif.isLocked ? "Unlock" : "Lock", systemImage: motif.isLocked ? "lock.open" : "lock")
                            }
                            Button(action: { duplicateMotif(motif) }) {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Button(action: { UIPasteboard.general.string = motif.imageName }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            Divider()
                            Button(role: .destructive, action: { deleteMotif(motif.id) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            if !motif.isLocked {
                                withAnimation {
                                    selectedMotifID = motif.id
                                    showMotifControls = true
                                }
                            }
                        }
                        .highPriorityGesture(
                            motif.isLocked ? nil :
                            DragGesture().onChanged { value in
                                motif.position = value.location
                                selectedMotifID = motif.id
                                showMotifControls = true
                            }
                        )
                }
            }
            .zIndex(showMotifControls ? 2.0 : 0.5) // Dynamic Z-Index to allow long-press while editing
            
            // LAYER 2: Drawing Surface
            DrawingCanvas(canvasView: $canvasView)
                .ignoresSafeArea()
                .zIndex(1)

            // LAYER 3: UI FIRST LAYER (Tool Rail & Top Bar)
            ZStack(alignment: .top) {
                if showUI {
                    topBarView
                    rightToolRail
                }
            }
            .zIndex(100)
            
            // LAYER 4: CONTEXTUAL CONTROLS
            if let selectedID = selectedMotifID, showMotifControls {
                motifPlacementControls(for: selectedID)
                    .zIndex(101)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showMotifSheet) {
            MotifGallery()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DropMotif"))) { note in
            if let imageName = note.object as? String {
                // This ensures the new instance uses your imageName (e.g., "sun_motif")
                let newMotif = MotifInstance(imageName: imageName, position: CGPoint(x: 400, y: 400))
                motifs.append(newMotif)
                selectedMotifID = newMotif.id
                showMotifControls = true
            }
        }
    }
    
    // MARK: - Placement Controls for Specific Motif
    func motifPlacementControls(for id: UUID) -> some View {
        VStack {
            Spacer()
            if let index = motifs.firstIndex(where: { $0.id == id }) {
                HStack(spacing: 20) {
                    Button(action: {
                        selectedMotifID = nil
                        showMotifControls = false
                    }) {
                        Text("Done").bold().foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(Color.mithilaGold))
                    }
                    
                    Slider(value: $motifs[index].scale, in: 0.5...2.5)
                        .accentColor(.mithilaGold)
                    
                    Button(action: {
                        motifs[index].isLocked = true
                        showMotifControls = false
                        selectedMotifID = nil
                    }) {
                        Image(systemName: "lock.fill").foregroundColor(.mithilaGold)
                            .padding(8).background(Circle().stroke(Color.mithilaGold, lineWidth: 1))
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemGroupedBackground)).shadow(radius: 10))
                .padding(.horizontal, 100).padding(.bottom, 40)
            }
        }
    }

    // MARK: - Subviews
    var topBarView: some View {
        VStack {
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.left").font(.title3.bold())
                        .foregroundColor(.lampBlack).padding(15)
                }
                Spacer()
                Button(action: { /* Save Logic */ }) {
                    Image(systemName: "square.and.arrow.down.fill").foregroundColor(.white)
                        .padding(10).background(Color.mithilaGold).clipShape(Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 10)
            Spacer()
        }
    }

    var rightToolRail: some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                Button(action: { isEraserActive = false; updateTool() }) {
                    Image(systemName: "pencil.tip").font(.title2)
                        .foregroundColor(!isEraserActive ? .mithilaGold : .gray)
                }

                VStack(spacing: 8) {
                    Button(action: { isEraserActive = true; updateTool() }) {
                        Image(systemName: "eraser.fill").font(.title2)
                            .foregroundColor(isEraserActive ? .mithilaGold : .gray)
                    }
                    if isEraserActive {
                        ForEach([15, 30, 60], id: \.self) { size in
                            Circle()
                                .fill(eraserSize == CGFloat(size) ? Color.mithilaGold : Color.gray.opacity(0.3))
                                .frame(width: CGFloat(size/3 + 5), height: CGFloat(size/3 + 5))
                                .onTapGesture { eraserSize = CGFloat(size); updateTool() }
                        }
                    }
                }
                
                Divider().frame(width: 30)
                
                VStack(spacing: 12) {
                    ForEach([Color.lampBlack, .deepVermillion, .turmericYellow, .indigoBlue, .green], id: \.self) { color in
                        Circle().fill(color).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.mithilaGold, lineWidth: (selectedColor == color && !isEraserActive) ? 3 : 0))
                            .onTapGesture { selectedColor = color; isEraserActive = false; updateTool() }
                    }
                }
                
                
                
                
                
                
                // Replace the current Lotus button in rightToolRail (line 227)
                Button(action: { showMotifSheet.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(Color.mithilaGold.opacity(0.15))
                            .frame(width: 44, height: 44)
                            
                        Image("lotus_art")
                            .renderingMode(.original) // 1. MUST BE FIRST
                            .resizable()              // 2. THEN RESIZABLE
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    }
                }
                
                Button(action: { canvasView.drawing = PKDrawing() }) {
                    Image(systemName: "arrow.counterclockwise").foregroundColor(.gray)
                }
            }
            .padding(.vertical, 25).padding(.horizontal, 12)
            .background(Capsule().fill(Color.white.opacity(0.95)).shadow(radius: 10))
            .padding(.trailing, 20).offset(y: 60)
        }
    }

    // MARK: - Logic Helpers
    func updateTool() {
        if isEraserActive {
            if #available(iOS 16.4, *) {
                canvasView.tool = PKEraserTool(.bitmap, width: eraserSize)
            } else {
                canvasView.tool = PKEraserTool(.bitmap)
            }
        } else {
            canvasView.tool = PKInkingTool(.pen, color: UIColor(selectedColor), width: 2)
        }
    }
    
    func duplicateMotif(_ motif: MotifInstance) {
        let newMotif = MotifInstance(
            imageName: motif.imageName, // Corrected from .name to .imageName
            position: CGPoint(x: motif.position.x + 40, y: motif.position.y + 40),
            scale: motif.scale
        )
        motifs.append(newMotif)
        selectedMotifID = newMotif.id
        showMotifControls = true
    }
    
    func deleteMotif(_ id: UUID) {
        motifs.removeAll { $0.id == id }
        selectedMotifID = nil
        showMotifControls = false
    }
    
    func copyToClipboard(_ name: String) {
        UIPasteboard.general.string = name
    }
}
