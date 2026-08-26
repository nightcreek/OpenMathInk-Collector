import Foundation
import PencilKit
import OpenMathInkDatasetCore

/// Converts PencilKit's transient drawing format into the independent,
/// InkML-inspired dataset representation. `PKDrawing` is never persisted by
/// this adapter.
enum DatasetInkDrawingAdapter {
    static func strokes(from drawing: PKDrawing) -> [InkStroke] {
        drawing.strokes.map { stroke in
            InkStroke(points: stroke.path.map { point in
                InkPoint(
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    timestamp: point.timeOffset,
                    pressure: min(max(Double(point.force), 0), 1),
                    altitude: Double(point.altitude),
                    azimuth: Double(point.azimuth)
                )
            })
        }
    }

    static func drawing(from data: Data?) -> PKDrawing {
        guard let data, let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }
}
