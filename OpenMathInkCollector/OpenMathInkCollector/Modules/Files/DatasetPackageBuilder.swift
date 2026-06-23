import Foundation

struct DatasetPackageBuilder {
    let fileManager = FileManager.default

    func buildPackage(
        samples: [MathInkSample],
        store: LocalSampleStore,
        targetDirectory: URL,
        consent: ContributorConsent
    ) throws -> URL {
        let timestamp = Self.timestampString(from: Date())
        let folderName = "OpenMathInkDataset_\(timestamp)"
        let packageRoot = targetDirectory.appendingPathComponent(folderName, isDirectory: true)
        let sampleRoot = packageRoot.appendingPathComponent("samples", isDirectory: true)

        try fileManager.createDirectory(at: packageRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sampleRoot, withIntermediateDirectories: true)

        let privacy = DatasetPrivacyInfo(
            containsPersonalIdentifiers: false,
            autoUploaded: false,
            userConfirmedExport: true
        )

        let manifest = DatasetManifest(
            datasetName: "OpenMathInk Dataset Export",
            version: "0.1.0",
            createdAt: Date(),
            sampleCount: samples.count,
            formatVersion: "openmathink.sample.v2",
            supportsAST: true,
            privacy: privacy
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: packageRoot.appendingPathComponent("manifest.json"), options: .atomic)

        let consentData = try encoder.encode(consent)
        try consentData.write(to: packageRoot.appendingPathComponent("consent.json"), options: .atomic)

        let licenseText = """
OpenMathInk Collector Export License Notice

This dataset package is voluntarily exported by the contributor.
No automatic upload is performed by this app.
Please review and comply with your target open-source dataset license.
"""
        try licenseText.data(using: .utf8)?.write(to: packageRoot.appendingPathComponent("license.txt"), options: .atomic)

        let privacyText = """
Privacy Notice

1. This app is used for voluntary math handwriting sample collection.
2. The app does not automatically upload any data.
3. All data is stored locally by default.
4. A dataset package is generated only after explicit user export action.
5. Exported data may be manually shared by the user to open-source projects.
6. Users should avoid personal identifiers inside formulas.
7. eMathica itself does not auto-collect notes/formulas through this app.
"""
        try privacyText.data(using: .utf8)?.write(to: packageRoot.appendingPathComponent("privacy_notice.txt"), options: .atomic)

        for (index, sample) in samples.enumerated() {
            let sampleID = String(format: "sample_%06d", index + 1)
            let sampleJSONURL = sampleRoot.appendingPathComponent("\(sampleID).json")
            let imageName = "\(sampleID).png"
            let drawingName = "\(sampleID).drawing"
            let astName = "\(sampleID).ast.json"

            let payload: [String: AnyCodable] = [
                "id": AnyCodable(sampleID),
                "latex": AnyCodable(sample.latex),
                "sourceText": AnyCodable(sample.sourceText),
                "computeExpression": AnyCodable(sample.computeExpression),
                "status": AnyCodable(sample.status.rawValue),
                "files": AnyCodable([
                    "image": AnyCodable(imageName),
                    "drawing": AnyCodable(drawingName),
                    "astJSON": AnyCodable(sample.astJSONFileName != nil ? astName : NSNull())
                ]),
                "canvas": AnyCodable([
                    "width": AnyCodable(sample.canvasWidth),
                    "height": AnyCodable(sample.canvasHeight)
                ]),
                "createdAt": AnyCodable(ISO8601DateFormatter().string(from: sample.createdAt)),
                "modifiedAt": AnyCodable(ISO8601DateFormatter().string(from: sample.modifiedAt))
            ]

            let sampleData = try JSONEncoder.pretty.encode(payload)
            try sampleData.write(to: sampleJSONURL, options: .atomic)

            if let drawingNameSource = sample.drawingDataFileName {
                let src = store.drawingsRoot.appendingPathComponent(drawingNameSource)
                if fileManager.fileExists(atPath: src.path) {
                    try fileManager.copyItem(at: src, to: sampleRoot.appendingPathComponent(drawingName))
                }
            }

            if let imageNameSource = sample.imageFileName {
                let src = store.imagesRoot.appendingPathComponent(imageNameSource)
                if fileManager.fileExists(atPath: src.path) {
                    try fileManager.copyItem(at: src, to: sampleRoot.appendingPathComponent(imageName))
                }
            }

            if let astSource = sample.astJSONFileName {
                let src = store.astRoot.appendingPathComponent(astSource)
                if fileManager.fileExists(atPath: src.path) {
                    try fileManager.copyItem(at: src, to: sampleRoot.appendingPathComponent(astName))
                }
            }
        }

        return packageRoot
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String: try container.encode(string)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let dict as [String: AnyCodable]: try container.encode(dict)
        case let array as [AnyCodable]: try container.encode(array)
        default: try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string; return }
        if let int = try? container.decode(Int.self) { value = int; return }
        if let double = try? container.decode(Double.self) { value = double; return }
        if let bool = try? container.decode(Bool.self) { value = bool; return }
        if let dict = try? container.decode([String: AnyCodable].self) { value = dict; return }
        if let array = try? container.decode([AnyCodable].self) { value = array; return }
        value = NSNull()
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
