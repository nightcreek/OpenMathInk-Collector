import SwiftUI
import PencilKit

#if os(iOS)
struct PencilDrawingRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data?
    @Binding var canvasSize: CGSize
    var onDrawingChanged: (PKDrawing, CGSize) -> Void
    
    @ObservedObject var toolSettings = DrawingToolSettings.shared
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = UIColor.secondarySystemBackground
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.tool = toolSettings.pkTool()
        canvas.bounds.size = canvasSize
        
        if let drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 更新工具
        uiView.tool = toolSettings.pkTool()
        
        // 更新画布尺寸
        if uiView.bounds.size != canvasSize {
            uiView.bounds.size = canvasSize
        }
        
        // 更新绘图数据
        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData),
           uiView.drawing.dataRepresentation() != drawingData {
            uiView.drawing = drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilDrawingRepresentable
        
        init(_ parent: PencilDrawingRepresentable) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            parent.drawingData = drawing.dataRepresentation()
            parent.onDrawingChanged(drawing, canvasView.bounds.size)
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            parent.drawingData = drawing.dataRepresentation()
            parent.onDrawingChanged(drawing, canvasView.bounds.size)
        }
    }
}
#elseif os(macOS)
import AppKit

struct PencilDrawingRepresentable: NSViewRepresentable {
    @Binding var drawingData: Data?
    @Binding var canvasSize: CGSize
    var onDrawingChanged: (PKDrawing, CGSize) -> Void
    
    @ObservedObject var toolSettings = DrawingToolSettings.shared
    
    func makeNSView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .windowBackgroundColor
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = toolSettings.pkTool()
        canvas.bounds.size = canvasSize
        
        if let drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        
        return canvas
    }
    
    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        nsView.tool = toolSettings.pkTool()
        
        if nsView.bounds.size != canvasSize {
            nsView.bounds.size = canvasSize
        }
        
        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData),
           nsView.drawing.dataRepresentation() != drawingData {
            nsView.drawing = drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilDrawingRepresentable
        
        init(_ parent: PencilDrawingRepresentable) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            parent.drawingData = drawing.dataRepresentation()
            parent.onDrawingChanged(drawing, canvasView.bounds.size)
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            parent.drawingData = drawing.dataRepresentation()
            parent.onDrawingChanged(drawing, canvasView.bounds.size)
        }
    }
}
#endif
