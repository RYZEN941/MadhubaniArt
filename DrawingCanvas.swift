import SwiftUI
import PencilKit
import UIKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var snapLine:      Bool = false
    var snapCircle:    Bool = false
    var onStrokeBegin: (() -> Void)? = nil
    var onStrokeEnd:   (() -> Void)? = nil

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled   = true
        canvasView.minimumZoomScale  = 0.25
        canvasView.maximumZoomScale  = 8.0
        canvasView.bouncesZoom       = true
        canvasView.showsVerticalScrollIndicator   = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.contentSize = CGSize(width: 4000, height: 4000)
        canvasView.zoomScale = 1.0
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.addInteraction(UIDropInteraction(delegate: context.coordinator))
        canvasView.delegate = context.coordinator
        canvasView.becomeFirstResponder()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.snapLine   = snapLine
        context.coordinator.snapCircle = snapCircle
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDropInteractionDelegate, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        var snapLine:   Bool = false
        var snapCircle: Bool = false
        // Track stroke count so we know exactly when one new stroke was added
        private var strokeCountAtBegin = 0
        private var isSnapping = false   // guard against re-entry during snap replacement

        init(_ p: DrawingCanvas) { parent = p }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            strokeCountAtBegin = canvasView.drawing.strokes.count
            parent.onStrokeBegin?()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // FIX 7: snap replacement — must not re-trigger itself
            guard !isSnapping else { return }
            guard snapLine || snapCircle else { parent.onStrokeEnd?(); return }

            let strokes = canvasView.drawing.strokes
            // Only act when exactly ONE new stroke was just added
            guard strokes.count == strokeCountAtBegin + 1 else { parent.onStrokeEnd?(); return }

            let rawStroke = strokes.last!
            let points = rawStroke.path.map { $0 }
            guard points.count >= 2 else { parent.onStrokeEnd?(); return }

            let first = points.first!.location
            let last  = points.last!.location
            let ink   = rawStroke.ink

            // Helper to build a PKStrokePoint at a given location
            func pt(_ loc: CGPoint, _ t: Double) -> PKStrokePoint {
                PKStrokePoint(location: loc, timeOffset: t,
                              size: CGSize(width: rawStroke.path[0].size.width,
                                           height: rawStroke.path[0].size.height),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi/2)
            }

            var snapStroke: PKStroke
            if snapLine {
                // FIX 7: straight line — 2 points, first → last, in the SAME coordinate space
                let path = PKStrokePath(controlPoints: [pt(first, 0), pt(last, 0.001)],
                                        creationDate: Date())
                snapStroke = PKStroke(ink: ink, path: path)
            } else {
                // FIX 5: use bounding box of ALL stroke points so circle matches what the user drew
                // regardless of gesture direction (diagonal, horizontal, circular, etc.)
                let xs = points.map { $0.location.x }
                let ys = points.map { $0.location.y }
                let minX = xs.min()!, maxX = xs.max()!
                let minY = ys.min()!, maxY = ys.max()!
                let cx = (minX + maxX) / 2
                let cy = (minY + maxY) / 2
                // Radius = half of the larger dimension, so circle encloses the gesture
                let radius = max(maxX - minX, maxY - minY) / 2

                let steps = 72
                var circlePts: [PKStrokePoint] = []
                for i in 0...steps {
                    let angle = 2.0 * Double.pi * Double(i) / Double(steps)
                    let x = cx + radius * CGFloat(cos(angle))
                    let y = cy + radius * CGFloat(sin(angle))
                    circlePts.append(pt(CGPoint(x: x, y: y), Double(i) * 0.001))
                }
                let path = PKStrokePath(controlPoints: circlePts, creationDate: Date())
                snapStroke = PKStroke(ink: ink, path: path)
            }

            // Replace last stroke with snapped version
            isSnapping = true
            var newDrawing = canvasView.drawing
            newDrawing.strokes.removeLast()
            newDrawing.strokes.append(snapStroke)
            canvasView.drawing = newDrawing
            isSnapping = false

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
