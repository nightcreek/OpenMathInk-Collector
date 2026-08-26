import PencilKit
import SwiftUI

/// PencilKit capture surface used only while authoring a sample. The caller
/// receives a `PKDrawing`, then immediately adapts it to `InkStroke` values.
struct DatasetPencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    let onDrawingChanged: (PKDrawing, CGSize) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .secondarySystemBackground
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvas.drawing = DatasetInkDrawingAdapter.drawing(from: drawingData)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let drawing = DatasetInkDrawingAdapter.drawing(from: drawingData)
        if canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private var parent: DatasetPencilCanvasView

        init(_ parent: DatasetPencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            parent.drawingData = drawing.dataRepresentation()
            parent.onDrawingChanged(drawing, canvasView.bounds.size)
        }
    }
}
