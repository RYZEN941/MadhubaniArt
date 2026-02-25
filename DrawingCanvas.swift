import SwiftUI
import PencilKit
import UIKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var onStrokeBegin: (() -> Void)? = nil
    var onStrokeEnd:   (() -> Void)? = nil

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput

        // CLEAR background so motif layer beneath always shows through
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // Native pinch-to-zoom & pan — this is what Freeform uses
        canvasView.isScrollEnabled   = true
        canvasView.minimumZoomScale  = 0.25
        canvasView.maximumZoomScale  = 8.0
        canvasView.bouncesZoom       = true
        canvasView.showsVerticalScrollIndicator   = false
        canvasView.showsHorizontalScrollIndicator = false

        // Large content size so you always have room to scroll
        canvasView.contentSize = CGSize(width: 4000, height: 4000)

        // Start centred at a comfortable zoom
        canvasView.zoomScale = 1.0

        // Tool default
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)

        // Drop interaction so motifs can be dragged from the gallery
        canvasView.addInteraction(UIDropInteraction(delegate: context.coordinator))
        canvasView.delegate = context.coordinator
        canvasView.becomeFirstResponder()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDropInteractionDelegate, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        init(_ p: DrawingCanvas) { parent = p }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            parent.onStrokeBegin?()
        }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onStrokeEnd?()
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            session.loadObjects(ofClass: NSString.self) { items in
                guard let name = items.first as? String else { return }
                NotificationCenter.default.post(name: NSNotification.Name("DropMotif"), object: name)
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: .copy)
        }
    }
}
