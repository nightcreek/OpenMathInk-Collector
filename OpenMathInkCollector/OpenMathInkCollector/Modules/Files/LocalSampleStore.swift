import Foundation
import PencilKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

final class LocalSampleStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let rootDirectory: URL
    private let samplesDirectory: URL
    private let drawingsDirectory: URL
    private let imagesDirectory: URL
    private let astDirectory: URL
    private let indexFileURL: URL

    init(baseURL: URL? = nil) {
        let base: URL
        if let provided = baseURL {
            base = provided
        } else if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            base = documentsURL
        } else {
            // 降级到临时目录
            base = fileManager.temporaryDirectory
        }
        rootDirectory = base.appendingPathComponent("OpenMathInkCollector", isDirectory: true)
        samplesDirectory = rootDirectory.appendingPathComponent("samples", isDirectory: true)
        drawingsDirectory = rootDirectory.appendingPathComponent("drawings", isDirectory: true)
        imagesDirectory = rootDirectory.appendingPathComponent("images", isDirectory: true)
        astDirectory = rootDirectory.appendingPathComponent("ast", isDirectory: true)
        indexFileURL = rootDirectory.appendingPathComponent("samples_index.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            try bootstrapDirectories()
        } catch {
            print("LocalSampleStore: Failed to create directories: \(error.localizedDescription)")
        }
    }

    private func bootstrapDirectories() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: samplesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: astDirectory, withIntermediateDirectories: true)
    }

    func loadSamples() throws -> [MathInkSample] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else { return [] }
        let data = try Data(contentsOf: indexFileURL)
        return try decoder.decode([MathInkSample].self, from: data)
    }

    func persistSampleIndex(_ samples: [MathInkSample]) throws {
        let data = try encoder.encode(samples.sorted(by: { $0.createdAt < $1.createdAt }))
        try data.write(to: indexFileURL, options: .atomic)
    }

    func saveDrawing(_ drawing: PKDrawing, sampleID: UUID, canvasSize: CGSize) throws -> (drawingFileName: String, imageFileName: String) {
        let drawingName = "\(sampleID.uuidString).drawing"
        let imageName = "\(sampleID.uuidString).png"

        let drawingURL = drawingsDirectory.appendingPathComponent(drawingName)
        try drawing.dataRepresentation().write(to: drawingURL, options: .atomic)

        #if canImport(UIKit)
        let image = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: UIScreen.main.scale)
        if let pngData = image.pngData() {
            try pngData.write(to: imagesDirectory.appendingPathComponent(imageName), options: .atomic)
        }
        #elseif canImport(AppKit)
        let image = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 2.0)
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            try pngData.write(to: imagesDirectory.appendingPathComponent(imageName), options: .atomic)
        }
        #endif

        return (drawingName, imageName)
    }

    func loadDrawingData(fileName: String?) -> Data? {
        guard let fileName else { return nil }
        return try? Data(contentsOf: drawingsDirectory.appendingPathComponent(fileName))
    }

    func saveASTJSON(_ data: Data, for sampleID: UUID) throws -> String {
        let fileName = "sample_\(sampleID.uuidString).ast.json"
        let fileURL = astDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }

    func loadASTJSON(fileName: String) throws -> Data {
        try Data(contentsOf: astDirectory.appendingPathComponent(fileName))
    }

    func deleteASTJSON(fileName: String?) throws {
        guard let fileName else { return }
        let url = astDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func imageURL(fileName: String?) -> URL? {
        guard let fileName else { return nil }
        let url = imagesDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func deleteSampleArtifacts(_ sample: MathInkSample) {
        if let drawing = sample.drawingDataFileName {
            try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(drawing))
        }
        if let image = sample.imageFileName {
            try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(image))
        }
        try? deleteASTJSON(fileName: sample.astJSONFileName)
        try? fileManager.removeItem(at: samplesDirectory.appendingPathComponent("\(sample.id.uuidString).json"))
    }

    func saveSampleMetadataJSON(_ sample: MathInkSample) throws {
        let file = samplesDirectory.appendingPathComponent("\(sample.id.uuidString).json")
        let data = try encoder.encode(sample)
        try data.write(to: file, options: .atomic)
    }

    var storageRoot: URL { rootDirectory }
    var drawingsRoot: URL { drawingsDirectory }
    var imagesRoot: URL { imagesDirectory }
    var astRoot: URL { astDirectory }

    func cleanupOrphanedFiles() throws {
        // 只加载一次，避免多次重复 I/O
        let samples: [MathInkSample]
        do {
            samples = try loadSamples()
        } catch {
            // 索引文件损坏时，跳过清理避免误删所有文件
            print("LocalSampleStore: 索引文件读取失败，跳过清理: \(error.localizedDescription)")
            return
        }

        let knownDrawingNames = Set(samples.compactMap(\.drawingDataFileName))
        let knownImageNames = Set(samples.compactMap(\.imageFileName))
        let knownASTNames = Set(samples.compactMap(\.astJSONFileName))
        let knownMetadataNames = Set(samples.map { "\($0.id.uuidString).json" })

        // 所有已知名称集合都为空时为异常状态，跳过清理
        if knownDrawingNames.isEmpty && knownImageNames.isEmpty
            && knownASTNames.isEmpty && knownMetadataNames.isEmpty {
            print("LocalSampleStore: 已知文件列表为空，跳过清理以避免误删")
            return
        }

        for (dir, knownNames) in [
            (drawingsDirectory, knownDrawingNames),
            (imagesDirectory, knownImageNames),
            (astDirectory, knownASTNames),
            (samplesDirectory, knownMetadataNames),
        ] {
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where !knownNames.contains(url.lastPathComponent) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    print("LocalSampleStore: 清理孤立文件失败: \(url.lastPathComponent) — \(error.localizedDescription)")
                }
            }
        }
    }
}
