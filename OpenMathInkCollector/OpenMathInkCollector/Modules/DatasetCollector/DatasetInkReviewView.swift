import OpenMathInkDatasetCore
import SwiftUI

/// Vector review of the persisted structured strokes. No screenshot, bitmap,
/// or `PKDrawing` is required to inspect a saved dataset sample.
struct DatasetInkReviewView: View {
    let sample: InkSample

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let scaleX = size.width / max(sample.canvas.width, 1)
                let scaleY = size.height / max(sample.canvas.height, 1)
                for stroke in sample.strokes where stroke.points.count > 1 {
                    var path = Path()
                    for (index, point) in stroke.points.enumerated() {
                        let location = CGPoint(x: point.x * scaleX, y: point.y * scaleY)
                        if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
                    }
                    context.stroke(path, with: .color(.primary), lineWidth: 2)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Structured ink stroke review")
        }
    }
}
