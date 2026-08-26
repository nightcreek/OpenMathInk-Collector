import Foundation
import OpenMathInkDatasetCore
import Testing

@Suite("OpenMathInk dataset core")
struct OpenMathInkDatasetCoreTests {
    @Test("creates saves loads and exports a structured InkML-style sample")
    func createSaveLoadExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try InkDatasetStore(rootURL: root)
        let sample = store.createSample(
            strokes: [.init(points: [
                .init(x: 1, y: 2, timestamp: 0, pressure: 0.4, altitude: 1.2, azimuth: 0.1),
                .init(x: 3, y: 4, timestamp: 0.1, pressure: 0.7, altitude: 1.1, azimuth: 0.2)
            ])],
            canvas: .init(width: 1024, height: 512, inputDevice: "Apple Pencil"),
            label: .init(
                rawLaTeX: "x^2",
                mathInput: .init(sourceText: "x^2", serializedAST: Data("ast".utf8))
            ),
            metadata: .init(createdAt: .init(timeIntervalSince1970: 0), updatedAt: .init(timeIntervalSince1970: 0))
        )

        try store.save(sample)
        let loaded = try store.load(id: sample.id)
        let manifest = try store.loadManifest()
        let exported = try store.exportDataset(samples: [loaded], to: root.appendingPathComponent("export", isDirectory: true))

        #expect(loaded == sample)
        #expect(loaded.boundingBox == .init(minX: 1, minY: 2, maxX: 3, maxY: 4))
        #expect(loaded.inkMLTraces.first?.coordinateSequence.contains("1.0 2.0") == true)
        #expect(manifest.sampleCount == 1)
        #expect(!manifest.datasetID.isEmpty)
        #expect(FileManager.default.fileExists(atPath: exported.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: exported.appendingPathComponent("samples/\(sample.id.uuidString).json").path))
    }

    @Test("validator reports missing strokes and invalid labels")
    func validatorReportsInvalidSamples() {
        let sample = InkSample(
            strokes: [],
            canvas: .init(width: 100, height: 100),
            label: .init(rawLaTeX: " ")
        )
        let codes = Set(InkSampleValidator.validate(sample).map(\.code))

        #expect(codes.contains(.missingStrokes))
        #expect(codes.contains(.invalidLabel))
    }

    @Test("validator reports corrupted encoded samples")
    func validatorReportsCorruption() {
        let issues = InkSampleValidator.validate(encodedSample: Data("not-json".utf8))
        #expect(issues.map(\.code) == [.corruptedSample])
    }

    @Test("lists persisted samples without requiring rendered assets")
    func loadAllReturnsStableStructuredSamples() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try InkDatasetStore(rootURL: root)
        let first = store.createSample(
            strokes: [.init(points: [.init(x: 0, y: 0, timestamp: 0)])],
            canvas: .init(width: 10, height: 10),
            label: .init(rawLaTeX: "x"),
            metadata: .init(createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 1))
        )
        let second = store.createSample(
            strokes: [.init(points: [.init(x: 1, y: 1, timestamp: 0)])],
            canvas: .init(width: 10, height: 10),
            label: .init(rawLaTeX: "y"),
            metadata: .init(createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 2))
        )

        try store.save(second)
        try store.save(first)

        #expect(try store.loadAll().map(\.id) == [first.id, second.id])
    }

    @Test("persists a versioned prompt corpus and preserves raw and canonical labels")
    func promptCorpusAndCanonicalLabelsPersist() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try InkDatasetStore(rootURL: root)
        let corpus = InkPromptCorpus(
            id: "test.corpus",
            version: "7.1.0",
            prompts: [.init(
                id: "fraction.one-half",
                expectedCanonicalLaTeX: "\\frac{1}{2}",
                category: .fraction,
                difficulty: 2,
                corpusVersion: "7.1.0"
            )]
        )
        try store.savePromptCorpus(corpus)
        let sample = InkSample(
            strokes: [stroke()],
            canvas: canvas(),
            label: .init(rawLaTeX: "\\frac { 1 } { 2 }", canonicalLaTeX: "\\frac{1}{2}"),
            metadata: .init(provenance: .init(
                promptID: "fraction.one-half",
                corpusVersion: "7.1.0",
                anonymousWriterID: "writer-01",
                inputDeviceCategory: .applePencil,
                orientation: .landscape
            ))
        )

        try store.save(sample, corpus: corpus)
        let storedCorpus = try store.loadPromptCorpus()
        let loaded = try #require(storedCorpus)
        let loadedSample = try store.load(id: sample.id)

        #expect(loaded.id == corpus.id)
        #expect(loaded.version == corpus.version)
        #expect(loaded.prompts == corpus.prompts)
        #expect(loadedSample.label.rawLaTeX == "\\frac { 1 } { 2 }")
        #expect(loadedSample.label.canonicalLaTeX == "\\frac{1}{2}")
    }

    @Test("coverage reports prompt progress and missing categories")
    func coverageReportsProgress() {
        let corpus = InkPromptCorpus(
            id: "test.corpus",
            version: "1",
            prompts: [
                .init(id: "symbol.x", expectedCanonicalLaTeX: "x", category: .individualSymbol, difficulty: 1, corpusVersion: "1"),
                .init(id: "root.x", expectedCanonicalLaTeX: "\\sqrt{x}", category: .root, difficulty: 2, corpusVersion: "1")
            ]
        )
        let sample = promptedSample(promptID: "symbol.x", canonical: "x", writer: "writer-01", corpusVersion: "1")

        let statistics = InkDatasetAnalyzer.coverage(samples: [sample], corpus: corpus)

        #expect(statistics.promptCoverage.first(where: { $0.promptID == "symbol.x" })?.sampleCount == 1)
        #expect(statistics.underrepresentedPromptIDs == ["root.x"])
        #expect(statistics.categoryDistribution[.individualSymbol] == 1)
        #expect(statistics.underrepresentedCategories.contains(.root))
        #expect(statistics.expressionFrequency["x"] == 1)
        #expect(statistics.strokeCountDistribution[1] == 1)
    }

    @Test("writer-aware split is deterministic and has no writer leakage")
    func writerAwareSplitHasNoLeakage() {
        let samples = [
            promptedSample(promptID: "a", canonical: "a", writer: "writer-01", corpusVersion: "1"),
            promptedSample(promptID: "b", canonical: "b", writer: "writer-01", corpusVersion: "1"),
            promptedSample(promptID: "c", canonical: "c", writer: "writer-02", corpusVersion: "1")
        ]

        let first = InkWriterAwareSplitGenerator.makeAssignments(samples: samples)
        let second = InkWriterAwareSplitGenerator.makeAssignments(samples: samples)
        let issues = InkDatasetValidator.validate(samples: samples, splitAssignments: first)

        #expect(first == second)
        #expect(first.sampleAssignments[samples[0].id] == first.sampleAssignments[samples[1].id])
        #expect(!issues.contains(where: { $0.code == .writerSplitLeakage }))
    }

    @Test("validator detects canonical mismatches and split leakage")
    func validatorDetectsProtocolViolations() {
        let corpus = InkPromptCorpus(
            id: "test.corpus",
            version: "1",
            prompts: [.init(id: "symbol.x", expectedCanonicalLaTeX: "x", category: .individualSymbol, difficulty: 1, corpusVersion: "1")]
        )
        let first = promptedSample(promptID: "symbol.x", canonical: "y", writer: "writer-01", corpusVersion: "1")
        let second = promptedSample(promptID: "symbol.x", canonical: "x", writer: "writer-01", corpusVersion: "1")
        let splits = InkDatasetSplitAssignments(
            writerAssignments: ["writer:writer-01": .train],
            sampleAssignments: [first.id: .train, second.id: .test]
        )

        let issues = InkDatasetValidator.validate(samples: [first, second], corpus: corpus, splitAssignments: splits)
        let codes = Set(issues.map(\.code))

        #expect(codes.contains(.canonicalLabelMismatch))
        #expect(codes.contains(.writerSplitLeakage))
    }

    @Test("validator detects unknown prompts and duplicate sample IDs")
    func validatorDetectsUnknownPromptAndDuplicates() {
        let corpus = InkPromptCorpus(
            id: "test.corpus",
            version: "1",
            prompts: [.init(id: "known", expectedCanonicalLaTeX: "x", category: .individualSymbol, difficulty: 1, corpusVersion: "1")]
        )
        let sample = promptedSample(promptID: "unknown", canonical: "x", writer: "writer-01", corpusVersion: "1")

        let issues = InkDatasetValidator.validate(samples: [sample, sample], corpus: corpus)
        let codes = Set(issues.map(\.code))

        #expect(codes.contains(.unknownPromptReference))
        #expect(codes.contains(.duplicateSampleID))
    }

    @Test("samples without protocol fields decode as existing free-form samples")
    func existingSampleCompatibility() throws {
        let sample = InkSample(strokes: [stroke()], canvas: canvas(), label: .init(rawLaTeX: "x^2"))
        let encoded = try InkSampleJSONCodec.encode(sample)
        let decoded = try InkSampleJSONCodec.decode(encoded)

        #expect(decoded.label.rawLaTeX == "x^2")
        #expect(decoded.label.canonicalLaTeX == nil)
        #expect(decoded.metadata.provenance == nil)
        #expect(InkSampleValidator.validate(decoded).isEmpty)
    }

    private func stroke() -> InkStroke {
        .init(points: [
            .init(x: 0, y: 0, timestamp: 0, pressure: 0.5),
            .init(x: 10, y: 10, timestamp: 1, pressure: 0.8)
        ])
    }

    private func canvas() -> InkCanvasMetadata {
        .init(width: 100, height: 100, inputDevice: "Apple Pencil")
    }

    private func promptedSample(
        promptID: String,
        canonical: String,
        writer: String,
        corpusVersion: String
    ) -> InkSample {
        InkSample(
            strokes: [stroke()],
            canvas: canvas(),
            label: .init(rawLaTeX: canonical, canonicalLaTeX: canonical),
            metadata: .init(provenance: .init(
                promptID: promptID,
                corpusVersion: corpusVersion,
                anonymousWriterID: writer,
                inputDeviceCategory: .applePencil,
                orientation: .landscape
            ))
        )
    }
}
