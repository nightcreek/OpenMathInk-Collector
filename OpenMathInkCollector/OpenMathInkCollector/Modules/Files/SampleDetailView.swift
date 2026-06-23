import SwiftUI

struct SampleDetailView: View {
    let sample: MathInkSample
    let imageURL: URL?
    @State private var loadedImageData: Data?
    @State private var isLoading = false
    @State private var showDebugFields = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("样本详情")
                .font(.headline)

            ThumbnailImageView(data: loadedImageData, isLoading: isLoading)

            Text("状态: \(sample.status.displayName)")
                .font(.caption)
            Text("canvas: \(Int(sample.canvasWidth)) x \(Int(sample.canvasHeight))")
                .font(.caption2)

            DisclosureGroup("导出字段 / Debug", isExpanded: $showDebugFields) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("latex: \(sample.latex)")
                    Text("sourceText: \(sample.sourceText)")
                    Text("computeExpression: \(sample.computeExpression)")
                    Text("astJSONFileName: \(sample.astJSONFileName ?? "-")")
                    Text("drawing file: \(sample.drawingDataFileName ?? "-")")
                    Text("image file: \(sample.imageFileName ?? "-")")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = imageURL else {
            loadedImageData = nil
            return
        }
        isLoading = true
        loadedImageData = await PlatformImageLoader.loadData(from: url)
        isLoading = false
    }
}

/// 跨平台缩略图视图
#if canImport(UIKit)
private struct ThumbnailImageView: UIViewRepresentable {
    let data: Data?
    let isLoading: Bool

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        if isLoading {
            imageView.image = nil
            imageView.backgroundColor = .secondarySystemBackground
        } else if let data, let image = UIImage(data: data) {
            imageView.image = image
            imageView.backgroundColor = .clear
        } else {
            imageView.image = nil
            imageView.backgroundColor = .secondarySystemBackground
            // 显示占位文字
            if imageView.subviews.isEmpty {
                let label = UILabel()
                label.text = "无缩略图"
                label.textColor = .secondaryLabel
                label.font = .preferredFont(forTextStyle: .caption2)
                label.textAlignment = .center
                imageView.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
                ])
            }
        }
    }
}
#else
private struct ThumbnailImageView: NSViewRepresentable {
    let data: Data?
    let isLoading: Bool

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        if isLoading {
            imageView.image = nil
            imageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        } else if let data, let image = NSImage(data: data) {
            imageView.image = image
            imageView.layer?.backgroundColor = nil
        } else {
            imageView.image = nil
            imageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }
}
#endif

struct SampleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = MathInkSample(
            id: UUID(),
            latex: "x^2 + y^2 = r^2",
            sourceText: "圆方程",
            computeExpression: "r = sqrt(x^2 + y^2)",
            astJSONFileName: "ast_001.json",
            drawingDataFileName: "draw_001.drawing",
            imageFileName: "img_001.png",
            canvasWidth: 1024,
            canvasHeight: 768,
            status: .confirmed,
            modifiedAt: Date()
        )
        SampleDetailView(sample: sample, imageURL: nil)
            .padding()
    }
}
