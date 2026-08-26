import Foundation

/// Foundation-only, InkML-inspired handwriting dataset model. It has no
/// dependency on PencilKit, Notebook, MathObject, CAS, or a recognizer.
public struct InkSample: Identifiable, Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let id: UUID
    public let schemaVersion: Int
    public var strokes: [InkStroke]
    public var boundingBox: InkBoundingBox?
    public var canvas: InkCanvasMetadata
    public var label: InkSampleLabel
    public var metadata: InkSampleMetadata

    public init(
        id: UUID = UUID(),
        strokes: [InkStroke],
        canvas: InkCanvasMetadata,
        label: InkSampleLabel,
        metadata: InkSampleMetadata = .init(),
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.strokes = strokes
        self.boundingBox = InkBoundingBox.enclosing(strokes.flatMap(\.points))
        self.canvas = canvas
        self.label = label
        self.metadata = metadata
    }

    /// InkML-compatible trace concepts, available without serializing XML.
    public var inkMLTraces: [InkMLCompatibleTrace] {
        strokes.map(InkMLCompatibleTrace.init)
    }

    public mutating func refreshBoundingBox() {
        boundingBox = InkBoundingBox.enclosing(strokes.flatMap(\.points))
        metadata.updatedAt = Date()
    }
}

/// A stroke point follows the InkML trace idea while retaining modern stylus
/// signals: position, relative timestamp, pressure, altitude, and azimuth.
public struct InkPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var timestamp: TimeInterval
    public var pressure: Double
    public var altitude: Double
    public var azimuth: Double

    public init(
        x: Double,
        y: Double,
        timestamp: TimeInterval,
        pressure: Double = 1,
        altitude: Double = .pi / 2,
        azimuth: Double = 0
    ) {
        self.x = x; self.y = y; self.timestamp = timestamp
        self.pressure = pressure; self.altitude = altitude; self.azimuth = azimuth
    }
}

public struct InkStroke: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var points: [InkPoint]

    public init(id: UUID = UUID(), points: [InkPoint]) {
        self.id = id
        self.points = points
    }
}

public struct InkBoundingBox: Hashable, Codable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY
    }

    public static func enclosing(_ points: [InkPoint]) -> Self? {
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce(
            .init(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        ) { box, point in
            .init(
                minX: min(box.minX, point.x), minY: min(box.minY, point.y),
                maxX: max(box.maxX, point.x), maxY: max(box.maxY, point.y)
            )
        }
    }
}

public enum InkCoordinateUnit: String, Hashable, Codable, Sendable {
    case points
    case pixels
    case normalized
}

public struct InkCanvasMetadata: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double
    public var coordinateUnit: InkCoordinateUnit
    public var inputDevice: String?
    public var displayScale: Double?

    public init(
        width: Double,
        height: Double,
        coordinateUnit: InkCoordinateUnit = .points,
        inputDevice: String? = nil,
        displayScale: Double? = nil
    ) {
        self.width = width; self.height = height; self.coordinateUnit = coordinateUnit
        self.inputDevice = inputDevice; self.displayScale = displayScale
    }
}

/// A label has a human-facing raw LaTeX representation and an optional
/// MathInput-compatible payload. The payload is opaque here by design: only
/// MathInput owns parsing and interpretation of its serialized AST.
public struct InkSampleLabel: Hashable, Codable, Sendable {
    public var rawLaTeX: String
    /// Canonical form supplied by a corpus or a host-owned canonicalization
    /// adapter. DatasetCore intentionally does not parse LaTeX itself.
    public var canonicalLaTeX: String?
    public var mathInput: MathInputCompatibleExpression?
    public var metadata: [String: String]

    public init(
        rawLaTeX: String,
        canonicalLaTeX: String? = nil,
        mathInput: MathInputCompatibleExpression? = nil,
        metadata: [String: String] = [:]
    ) {
        self.rawLaTeX = rawLaTeX
        self.canonicalLaTeX = canonicalLaTeX
        self.mathInput = mathInput
        self.metadata = metadata
    }
}

public struct MathInputCompatibleExpression: Hashable, Codable, Sendable {
    public var sourceText: String
    public var serializedAST: Data?
    public var formatIdentifier: String

    public init(
        sourceText: String,
        serializedAST: Data? = nil,
        formatIdentifier: String = "emathica.mathinput.ast"
    ) {
        self.sourceText = sourceText
        self.serializedAST = serializedAST
        self.formatIdentifier = formatIdentifier
    }
}

public struct InkSampleMetadata: Hashable, Codable, Sendable {
    public var createdAt: Date
    public var updatedAt: Date
    public var collectorVersion: String
    public var tags: [String: String]
    /// Non-identifying collection context. It is optional so schema-v1 samples
    /// remain decodable without migration data.
    public var provenance: InkSampleProvenance?

    public init(
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        collectorVersion: String = "openmathink.collector.foundation.v1",
        tags: [String: String] = [:],
        provenance: InkSampleProvenance? = nil
    ) {
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.collectorVersion = collectorVersion; self.tags = tags
        self.provenance = provenance
    }
}

// MARK: - Collection protocol

/// A host-provided canonicalizer boundary. MathInput may implement this in an
/// adapter package, while DatasetCore remains Foundation-only and parser-free.
public protocol InkLabelCanonicalizing: Sendable {
    func canonicalLaTeX(for rawLaTeX: String) throws -> String
}

public enum InkPromptCategory: String, CaseIterable, Hashable, Codable, Sendable {
    case individualSymbol
    case shortExpression
    case equation
    case fraction
    case root
    case powerOrSubscript
    case trigonometric
    case calculus
    case matrix
    case greekSymbol
    case complexNestedLayout
}

public struct InkPrompt: Identifiable, Hashable, Codable, Sendable {
    /// Stable corpus-defined identifier; never infer identity from a label.
    public let id: String
    public var expectedCanonicalLaTeX: String
    public var category: InkPromptCategory
    public var tags: [String]
    public var difficulty: Int
    public var corpusVersion: String

    public init(
        id: String,
        expectedCanonicalLaTeX: String,
        category: InkPromptCategory,
        tags: [String] = [],
        difficulty: Int,
        corpusVersion: String
    ) {
        self.id = id
        self.expectedCanonicalLaTeX = expectedCanonicalLaTeX
        self.category = category
        self.tags = tags
        self.difficulty = difficulty
        self.corpusVersion = corpusVersion
    }
}

public struct InkPromptCorpus: Hashable, Codable, Sendable, Identifiable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var version: String
    public var prompts: [InkPrompt]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        version: String,
        prompts: [InkPrompt],
        schemaVersion: Int = Self.currentSchemaVersion,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.version = version
        self.prompts = prompts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func prompt(id: String) -> InkPrompt? {
        prompts.first { $0.id == id }
    }

    /// A deliberately small starter corpus covering every collection category.
    /// Production programs are expected to persist and version their own corpus.
    public static let foundationV1 = InkPromptCorpus(
        id: "openmathink.foundation",
        version: "1.0.0",
        prompts: [
            .init(id: "symbol.x", expectedCanonicalLaTeX: "x", category: .individualSymbol, difficulty: 1, corpusVersion: "1.0.0"),
            .init(id: "expr.x-plus-1", expectedCanonicalLaTeX: "x+1", category: .shortExpression, difficulty: 1, corpusVersion: "1.0.0"),
            .init(id: "equation.linear", expectedCanonicalLaTeX: "x=1", category: .equation, difficulty: 1, corpusVersion: "1.0.0"),
            .init(id: "fraction.half", expectedCanonicalLaTeX: "\\frac{1}{2}", category: .fraction, difficulty: 2, corpusVersion: "1.0.0"),
            .init(id: "root.square", expectedCanonicalLaTeX: "\\sqrt{x}", category: .root, difficulty: 2, corpusVersion: "1.0.0"),
            .init(id: "power.square", expectedCanonicalLaTeX: "x^2", category: .powerOrSubscript, difficulty: 2, corpusVersion: "1.0.0"),
            .init(id: "trig.sin", expectedCanonicalLaTeX: "\\sin(x)", category: .trigonometric, difficulty: 2, corpusVersion: "1.0.0"),
            .init(id: "calculus.derivative", expectedCanonicalLaTeX: "\\frac{d}{dx}x^2", category: .calculus, difficulty: 3, corpusVersion: "1.0.0"),
            .init(id: "matrix.two-by-two", expectedCanonicalLaTeX: "\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}", category: .matrix, difficulty: 4, corpusVersion: "1.0.0"),
            .init(id: "greek.alpha", expectedCanonicalLaTeX: "\\alpha", category: .greekSymbol, difficulty: 1, corpusVersion: "1.0.0"),
            .init(id: "nested.integral", expectedCanonicalLaTeX: "\\int_0^1\\frac{1}{1+x^2}dx", category: .complexNestedLayout, difficulty: 5, corpusVersion: "1.0.0")
        ]
    )
}

public enum InkInputDeviceCategory: String, Hashable, Codable, Sendable {
    case applePencil
    case stylus
    case finger
    case mouseOrTrackpad
    case unknown
}

public enum InkCanvasOrientation: String, Hashable, Codable, Sendable {
    case portrait
    case landscape
    case square
    case unknown
}

/// All fields are non-identifying by contract. `anonymousWriterID` is a random
/// session/group key used only to prevent writer leakage across dataset splits.
public struct InkSampleProvenance: Hashable, Codable, Sendable {
    public var promptID: String?
    public var corpusVersion: String?
    public var anonymousWriterID: String?
    public var inputDeviceCategory: InkInputDeviceCategory?
    public var orientation: InkCanvasOrientation?
    public var collectionTimestamp: Date?

    public init(
        promptID: String? = nil,
        corpusVersion: String? = nil,
        anonymousWriterID: String? = nil,
        inputDeviceCategory: InkInputDeviceCategory? = nil,
        orientation: InkCanvasOrientation? = nil,
        collectionTimestamp: Date? = nil
    ) {
        self.promptID = promptID
        self.corpusVersion = corpusVersion
        self.anonymousWriterID = anonymousWriterID
        self.inputDeviceCategory = inputDeviceCategory
        self.orientation = orientation
        self.collectionTimestamp = collectionTimestamp
    }
}

public extension InkSample {
    var strokeCount: Int { strokes.count }
    var pointCount: Int { strokes.reduce(0) { $0 + $1.points.count } }
    var duration: TimeInterval {
        let timestamps = strokes.flatMap(\.points).map(\.timestamp)
        guard let minimum = timestamps.min(), let maximum = timestamps.max() else { return 0 }
        return max(0, maximum - minimum)
    }

    var collectionTimestamp: Date { metadata.provenance?.collectionTimestamp ?? metadata.createdAt }
}

public struct InkMLCompatibleTrace: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let points: [InkPoint]

    public init(_ stroke: InkStroke) {
        id = stroke.id
        points = stroke.points
    }

    /// A compact InkML-style coordinate sequence for interoperability tools.
    public var coordinateSequence: String {
        points.map { "\($0.x) \($0.y) \($0.timestamp) \($0.pressure)" }.joined(separator: ", ")
    }
}

public enum InkSampleValidationCode: String, Hashable, Codable, Sendable {
    case missingStrokes
    case emptyStroke
    case invalidPoint
    case invalidCanvas
    case invalidLabel
    case inconsistentBoundingBox
    case unsupportedSchemaVersion
    case corruptedSample
    case unknownPromptReference
    case canonicalLabelMismatch
    case invalidProvenance
    case duplicateSampleID
    case invalidCorpusVersion
    case writerSplitLeakage
}

public struct InkSampleValidationIssue: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var code: InkSampleValidationCode
    public var message: String

    public init(id: UUID = UUID(), code: InkSampleValidationCode, message: String) {
        self.id = id; self.code = code; self.message = message
    }
}

public enum InkSampleValidator {
    public static func validate(_ sample: InkSample, corpus: InkPromptCorpus? = nil) -> [InkSampleValidationIssue] {
        var issues: [InkSampleValidationIssue] = []
        if sample.schemaVersion != InkSample.currentSchemaVersion {
            issues.append(.init(code: .unsupportedSchemaVersion, message: "Unsupported InkSample schema version \(sample.schemaVersion)."))
        }
        if sample.strokes.isEmpty {
            issues.append(.init(code: .missingStrokes, message: "An InkSample must contain at least one stroke."))
        }
        for stroke in sample.strokes {
            if stroke.points.isEmpty {
                issues.append(.init(code: .emptyStroke, message: "Stroke \(stroke.id) has no points."))
            }
            for point in stroke.points where !isValid(point) {
                issues.append(.init(code: .invalidPoint, message: "Stroke \(stroke.id) contains a non-finite or invalid stylus point."))
                break
            }
        }
        if !sample.canvas.width.isFinite || !sample.canvas.height.isFinite || sample.canvas.width <= 0 || sample.canvas.height <= 0 {
            issues.append(.init(code: .invalidCanvas, message: "Canvas width and height must be finite positive values."))
        }
        let latex = sample.label.rawLaTeX.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sample.label.mathInput?.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if latex.isEmpty && source.isEmpty {
            issues.append(.init(code: .invalidLabel, message: "A raw LaTeX or MathInput-compatible label is required."))
        }
        if let provenance = sample.metadata.provenance {
            if let promptID = provenance.promptID, promptID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(code: .invalidProvenance, message: "Prompt IDs cannot be empty."))
            }
            if let writerID = provenance.anonymousWriterID, writerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(code: .invalidProvenance, message: "Anonymous writer IDs cannot be empty."))
            }
            if let promptID = provenance.promptID, let corpus {
                if let prompt = corpus.prompt(id: promptID) {
                    if provenance.corpusVersion != corpus.version || prompt.corpusVersion != corpus.version {
                        issues.append(.init(code: .invalidCorpusVersion, message: "Sample prompt provenance does not match corpus version \(corpus.version)."))
                    }
                    if sample.label.canonicalLaTeX != prompt.expectedCanonicalLaTeX {
                        issues.append(.init(code: .canonicalLabelMismatch, message: "Prompt \(promptID) requires its expected canonical LaTeX label."))
                    }
                } else {
                    issues.append(.init(code: .unknownPromptReference, message: "Prompt \(promptID) is not part of corpus \(corpus.id)."))
                }
            }
        }
        let calculatedBounds = InkBoundingBox.enclosing(sample.strokes.flatMap(\.points))
        if calculatedBounds != sample.boundingBox {
            issues.append(.init(code: .inconsistentBoundingBox, message: "Stored bounding box does not match stroke points."))
        }
        return issues
    }

    public static func validate(encodedSample data: Data, corpus: InkPromptCorpus? = nil) -> [InkSampleValidationIssue] {
        do {
            return validate(try InkSampleJSONCodec.decode(data), corpus: corpus)
        } catch {
            return [.init(code: .corruptedSample, message: "Unable to decode InkSample: \(error.localizedDescription)")]
        }
    }

    private static func isValid(_ point: InkPoint) -> Bool {
        point.x.isFinite && point.y.isFinite && point.timestamp.isFinite
            && point.pressure.isFinite && (0...1).contains(point.pressure)
            && point.altitude.isFinite && point.azimuth.isFinite
    }
}

public enum InkPromptCorpusValidator {
    public static func validate(_ corpus: InkPromptCorpus) -> [InkSampleValidationIssue] {
        var issues: [InkSampleValidationIssue] = []
        if corpus.schemaVersion != InkPromptCorpus.currentSchemaVersion {
            issues.append(.init(code: .unsupportedSchemaVersion, message: "Unsupported prompt corpus schema version \(corpus.schemaVersion)."))
        }
        if corpus.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || corpus.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: .invalidCorpusVersion, message: "A corpus requires non-empty ID and version values."))
        }
        var knownPromptIDs = Set<String>()
        for prompt in corpus.prompts {
            if prompt.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !knownPromptIDs.insert(prompt.id).inserted {
                issues.append(.init(code: .invalidProvenance, message: "Prompt IDs must be unique and non-empty."))
            }
            if prompt.expectedCanonicalLaTeX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(1...5).contains(prompt.difficulty) {
                issues.append(.init(code: .invalidProvenance, message: "Prompt \(prompt.id) requires canonical LaTeX and difficulty 1 through 5."))
            }
            if prompt.corpusVersion != corpus.version {
                issues.append(.init(code: .invalidCorpusVersion, message: "Prompt \(prompt.id) does not match corpus version \(corpus.version)."))
            }
        }
        return issues
    }
}

public enum InkSampleJSONCodec {
    public static func encode(_ sample: InkSample) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sample)
    }

    public static func decode(_ data: Data) throws -> InkSample {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(InkSample.self, from: data)
    }
}

public enum InkPromptCorpusJSONCodec {
    public static func encode(_ corpus: InkPromptCorpus) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(corpus)
    }

    public static func decode(_ data: Data) throws -> InkPromptCorpus {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(InkPromptCorpus.self, from: data)
    }
}

public struct InkDatasetManifest: Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 2
    public var schemaVersion: Int
    public var datasetID: String
    public var corpusVersion: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var sampleCount: Int
    public var sampleFormat: String

    public init(
        datasetID: String = UUID().uuidString,
        corpusVersion: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sampleCount: Int,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.datasetID = datasetID
        self.corpusVersion = corpusVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sampleCount = sampleCount
        self.sampleFormat = "openmathink.inkml-concepts.v1"
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, datasetID, corpusVersion, createdAt, updatedAt, sampleCount, sampleFormat
    }

    /// Decodes the original v1 export manifest too: those files did not carry
    /// a dataset ID, corpus version, or update timestamp.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        datasetID = try container.decodeIfPresent(String.self, forKey: .datasetID) ?? UUID().uuidString
        corpusVersion = try container.decodeIfPresent(String.self, forKey: .corpusVersion)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        sampleCount = try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
        sampleFormat = try container.decodeIfPresent(String.self, forKey: .sampleFormat) ?? "openmathink.inkml-concepts.v1"
    }
}

public struct InkPromptCoverage: Hashable, Codable, Sendable, Identifiable {
    public var id: String { promptID }
    public var promptID: String
    public var category: InkPromptCategory
    public var sampleCount: Int

    public init(promptID: String, category: InkPromptCategory, sampleCount: Int) {
        self.promptID = promptID
        self.category = category
        self.sampleCount = sampleCount
    }
}

public struct InkDatasetCoverageStatistics: Hashable, Codable, Sendable {
    public var promptCoverage: [InkPromptCoverage]
    public var categoryDistribution: [InkPromptCategory: Int]
    public var expressionFrequency: [String: Int]
    public var strokeCountDistribution: [Int: Int]
    public var durationDistribution: [String: Int]
    public var missingLabelCount: Int
    public var invalidLabelCount: Int

    public init(
        promptCoverage: [InkPromptCoverage],
        categoryDistribution: [InkPromptCategory: Int],
        expressionFrequency: [String: Int],
        strokeCountDistribution: [Int: Int],
        durationDistribution: [String: Int],
        missingLabelCount: Int,
        invalidLabelCount: Int
    ) {
        self.promptCoverage = promptCoverage
        self.categoryDistribution = categoryDistribution
        self.expressionFrequency = expressionFrequency
        self.strokeCountDistribution = strokeCountDistribution
        self.durationDistribution = durationDistribution
        self.missingLabelCount = missingLabelCount
        self.invalidLabelCount = invalidLabelCount
    }

    public var underrepresentedPromptIDs: [String] {
        promptCoverage.filter { $0.sampleCount == 0 }.map(\.promptID)
    }

    public var underrepresentedCategories: [InkPromptCategory] {
        InkPromptCategory.allCases.filter { categoryDistribution[$0, default: 0] == 0 }
    }
}

public enum InkDatasetAnalyzer {
    public static func coverage(
        samples: [InkSample],
        corpus: InkPromptCorpus? = nil
    ) -> InkDatasetCoverageStatistics {
        let promptCounts = samples.reduce(into: [String: Int]()) { counts, sample in
            if let promptID = sample.metadata.provenance?.promptID { counts[promptID, default: 0] += 1 }
        }
        let promptCoverage = corpus?.prompts.map {
            InkPromptCoverage(promptID: $0.id, category: $0.category, sampleCount: promptCounts[$0.id, default: 0])
        } ?? []
        var categoryDistribution: [InkPromptCategory: Int] = [:]
        if let corpus {
            for prompt in corpus.prompts {
                categoryDistribution[prompt.category, default: 0] += promptCounts[prompt.id, default: 0]
            }
        }
        var expressionFrequency: [String: Int] = [:]
        var strokeCountDistribution: [Int: Int] = [:]
        var durationDistribution: [String: Int] = [:]
        var missingLabelCount = 0
        var invalidLabelCount = 0
        for sample in samples {
            let raw = sample.label.rawLaTeX.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonical = sample.label.canonicalLaTeX?.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty && (canonical?.isEmpty ?? true) && (sample.label.mathInput?.sourceText.isEmpty ?? true) {
                missingLabelCount += 1
            }
            if !InkSampleValidator.validate(sample, corpus: corpus).isEmpty { invalidLabelCount += 1 }
            let expression = canonical?.isEmpty == false ? canonical! : raw
            if !expression.isEmpty { expressionFrequency[expression, default: 0] += 1 }
            strokeCountDistribution[sample.strokeCount, default: 0] += 1
            durationDistribution[durationBucket(for: sample.duration), default: 0] += 1
        }
        return .init(
            promptCoverage: promptCoverage,
            categoryDistribution: categoryDistribution,
            expressionFrequency: expressionFrequency,
            strokeCountDistribution: strokeCountDistribution,
            durationDistribution: durationDistribution,
            missingLabelCount: missingLabelCount,
            invalidLabelCount: invalidLabelCount
        )
    }

    private static func durationBucket(for duration: TimeInterval) -> String {
        switch duration {
        case ..<0.5: return "0-0.5s"
        case ..<1: return "0.5-1s"
        case ..<2: return "1-2s"
        case ..<5: return "2-5s"
        default: return "5s+"
        }
    }
}

public enum InkDatasetSplit: String, CaseIterable, Hashable, Codable, Sendable {
    case train
    case validation
    case test
}

public struct InkDatasetSplitConfiguration: Hashable, Codable, Sendable {
    public var trainFraction: Double
    public var validationFraction: Double

    public init(trainFraction: Double = 0.8, validationFraction: Double = 0.1) {
        self.trainFraction = trainFraction
        self.validationFraction = validationFraction
    }

    fileprivate var isValid: Bool {
        trainFraction > 0 && validationFraction > 0 && trainFraction + validationFraction < 1
    }
}

public struct InkDatasetSplitAssignments: Hashable, Codable, Sendable {
    public var writerAssignments: [String: InkDatasetSplit]
    public var sampleAssignments: [UUID: InkDatasetSplit]

    public init(writerAssignments: [String: InkDatasetSplit], sampleAssignments: [UUID: InkDatasetSplit]) {
        self.writerAssignments = writerAssignments
        self.sampleAssignments = sampleAssignments
    }
}

public enum InkWriterAwareSplitGenerator {
    /// Deterministic grouping by anonymous writer/session. Samples without one
    /// use their own ID as a one-sample group, preserving deterministic output.
    public static func makeAssignments(
        samples: [InkSample],
        configuration: InkDatasetSplitConfiguration = .init()
    ) -> InkDatasetSplitAssignments {
        precondition(configuration.isValid, "Split fractions must leave a non-zero test fraction.")
        let writerKeys = Set(samples.map(writerKey(for:))).sorted()
        var writerAssignments: [String: InkDatasetSplit] = [:]
        for key in writerKeys {
            let unit = Double(fnv1a64(key) % 10_000) / 10_000
            writerAssignments[key] = unit < configuration.trainFraction
                ? .train
                : unit < configuration.trainFraction + configuration.validationFraction ? .validation : .test
        }
        let sampleAssignments = Dictionary(uniqueKeysWithValues: samples.map { sample in
            (sample.id, writerAssignments[writerKey(for: sample)]!)
        })
        return .init(writerAssignments: writerAssignments, sampleAssignments: sampleAssignments)
    }

    public static func writerKey(for sample: InkSample) -> String {
        if let writerID = sample.metadata.provenance?.anonymousWriterID,
           !writerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "writer:\(writerID)"
        }
        return "sample:\(sample.id.uuidString)"
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

public enum InkDatasetValidator {
    public static func validate(
        samples: [InkSample],
        corpus: InkPromptCorpus? = nil,
        splitAssignments: InkDatasetSplitAssignments? = nil
    ) -> [InkSampleValidationIssue] {
        var issues: [InkSampleValidationIssue] = []
        var knownSampleIDs = Set<UUID>()
        for sample in samples {
            if !knownSampleIDs.insert(sample.id).inserted {
                issues.append(.init(code: .duplicateSampleID, message: "Dataset contains duplicate sample ID \(sample.id)."))
            }
            issues.append(contentsOf: InkSampleValidator.validate(sample, corpus: corpus))
        }
        guard let splitAssignments else { return issues }
        var observedSplits: [String: Set<InkDatasetSplit>] = [:]
        for sample in samples {
            guard let assignment = splitAssignments.sampleAssignments[sample.id] else {
                issues.append(.init(code: .writerSplitLeakage, message: "Sample \(sample.id) has no split assignment."))
                continue
            }
            let writerKey = InkWriterAwareSplitGenerator.writerKey(for: sample)
            observedSplits[writerKey, default: []].insert(assignment)
            if let expected = splitAssignments.writerAssignments[writerKey], expected != assignment {
                issues.append(.init(code: .writerSplitLeakage, message: "Sample \(sample.id) differs from its writer/session split assignment."))
            }
        }
        for (writer, splits) in observedSplits where splits.count > 1 {
            issues.append(.init(code: .writerSplitLeakage, message: "Anonymous writer/session \(writer) appears in multiple dataset splits."))
        }
        return issues
    }
}

/// File-based dataset store for collection tools. Samples are JSON files with
/// structured traces; no image generation, OCR, training, or model artifacts.
public final class InkDatasetStore {
    private let fileManager: FileManager
    public let rootURL: URL

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
        self.fileManager = fileManager
        try fileManager.createDirectory(at: samplesURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: manifestURL.path) {
            let initialCount = try fileManager.contentsOfDirectory(at: samplesURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" }
                .count
            try writeManifest(.init(sampleCount: initialCount))
        }
    }

    public func createSample(
        strokes: [InkStroke],
        canvas: InkCanvasMetadata,
        label: InkSampleLabel,
        metadata: InkSampleMetadata = .init()
    ) -> InkSample {
        .init(strokes: strokes, canvas: canvas, label: label, metadata: metadata)
    }

    public func save(_ sample: InkSample, corpus: InkPromptCorpus? = nil) throws {
        let issues = InkSampleValidator.validate(sample, corpus: corpus)
        guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
        try InkSampleJSONCodec.encode(sample).write(to: sampleURL(for: sample.id), options: .atomic)
        var manifest = try loadManifest()
        manifest.sampleCount = try sampleFileCount()
        manifest.corpusVersion = corpus?.version ?? manifest.corpusVersion
        manifest.updatedAt = Date()
        try writeManifest(manifest)
    }

    public func load(id: UUID) throws -> InkSample {
        let data = try Data(contentsOf: sampleURL(for: id))
        let issues = InkSampleValidator.validate(encodedSample: data)
        guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
        return try InkSampleJSONCodec.decode(data)
    }

    public func savePromptCorpus(_ corpus: InkPromptCorpus) throws {
        let issues = InkPromptCorpusValidator.validate(corpus)
        guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
        try InkPromptCorpusJSONCodec.encode(corpus).write(to: promptCorpusURL, options: .atomic)
        var manifest = try loadManifest()
        manifest.corpusVersion = corpus.version
        manifest.updatedAt = Date()
        try writeManifest(manifest)
    }

    public func loadPromptCorpus() throws -> InkPromptCorpus? {
        guard fileManager.fileExists(atPath: promptCorpusURL.path) else { return nil }
        let data = try Data(contentsOf: promptCorpusURL)
        let corpus = try InkPromptCorpusJSONCodec.decode(data)
        let issues = InkPromptCorpusValidator.validate(corpus)
        guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
        return corpus
    }

    public func loadManifest() throws -> InkDatasetManifest {
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(InkDatasetManifest.self, from: data)
    }

    /// Loads every persisted sample in a stable order. This is intentionally a
    /// structured-data operation: collectors never need to read a rendered
    /// image to list or inspect their samples.
    public func loadAll() throws -> [InkSample] {
        let urls = try fileManager.contentsOfDirectory(
            at: samplesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let data = try Data(contentsOf: url)
                let issues = InkSampleValidator.validate(encodedSample: data)
                guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
                return try InkSampleJSONCodec.decode(data)
            }
            .sorted { $0.metadata.createdAt < $1.metadata.createdAt }
    }

    public func exportDataset(
        samples: [InkSample],
        to targetDirectory: URL,
        corpus: InkPromptCorpus? = nil,
        splitAssignments: InkDatasetSplitAssignments? = nil
    ) throws -> URL {
        if let corpus {
            let corpusIssues = InkPromptCorpusValidator.validate(corpus)
            guard corpusIssues.isEmpty else { throw InkDatasetStoreError.invalidSample(corpusIssues) }
        }
        for sample in samples {
            let issues = InkSampleValidator.validate(sample, corpus: corpus)
            guard issues.isEmpty else { throw InkDatasetStoreError.invalidSample(issues) }
        }
        let datasetIssues = InkDatasetValidator.validate(samples: samples, corpus: corpus, splitAssignments: splitAssignments)
        guard datasetIssues.isEmpty else { throw InkDatasetStoreError.invalidSample(datasetIssues) }
        let exportURL = targetDirectory.appendingPathComponent("OpenMathInkDataset", isDirectory: true)
        let exportSamplesURL = exportURL.appendingPathComponent("samples", isDirectory: true)
        try fileManager.createDirectory(at: exportSamplesURL, withIntermediateDirectories: true)
        var manifest = try loadManifest()
        manifest.schemaVersion = InkDatasetManifest.currentSchemaVersion
        manifest.corpusVersion = corpus?.version ?? manifest.corpusVersion
        manifest.sampleCount = samples.count
        manifest.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: exportURL.appendingPathComponent("manifest.json"), options: .atomic)
        if let corpus {
            try InkPromptCorpusJSONCodec.encode(corpus).write(to: exportURL.appendingPathComponent("prompt-corpus.json"), options: .atomic)
        }
        if let splitAssignments {
            try encoder.encode(splitAssignments).write(to: exportURL.appendingPathComponent("splits.json"), options: .atomic)
        }
        for sample in samples {
            try InkSampleJSONCodec.encode(sample).write(
                to: exportSamplesURL.appendingPathComponent("\(sample.id.uuidString).json"),
                options: .atomic
            )
        }
        return exportURL
    }

    private var samplesURL: URL { rootURL.appendingPathComponent("samples", isDirectory: true) }
    private var manifestURL: URL { rootURL.appendingPathComponent("manifest.json", isDirectory: false) }
    private var promptCorpusURL: URL { rootURL.appendingPathComponent("prompt-corpus.json", isDirectory: false) }
    private func sampleURL(for id: UUID) -> URL {
        samplesURL.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func sampleFileCount() throws -> Int {
        try fileManager.contentsOfDirectory(at: samplesURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
            .count
    }

    private func writeManifest(_ manifest: InkDatasetManifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }
}

public enum InkDatasetStoreError: Error {
    case invalidSample([InkSampleValidationIssue])
}
