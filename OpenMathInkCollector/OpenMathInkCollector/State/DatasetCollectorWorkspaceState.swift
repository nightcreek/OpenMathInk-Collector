import Combine
import Foundation
import PencilKit
import OpenMathInkDatasetCore

enum DatasetCollectionMode: String, CaseIterable, Identifiable {
    case freeForm
    case prompted

    var id: String { rawValue }
    var title: String { self == .freeForm ? "Free-form" : "Prompted" }
}

/// UI-facing coordinator for dataset collection. It owns only a temporary
/// PencilKit drawing while a sample is edited; its durable state is always an
/// `InkSample` managed by `InkDatasetStore`.
@MainActor
final class DatasetCollectorWorkspaceState: ObservableObject {
    @Published private(set) var samples: [InkSample] = []
    @Published private(set) var selectedSampleID: UUID?
    @Published private(set) var draftID = UUID()
    @Published private(set) var draftStrokes: [InkStroke] = []
    @Published private(set) var draftCanvas = InkCanvasMetadata(width: 1, height: 1, inputDevice: "Apple Pencil")
    @Published var rawLaTeX = ""
    @Published private(set) var canonicalLaTeX: String?
    @Published private(set) var mathInputLabel: MathInputCompatibleExpression?
    @Published var drawingData: Data?
    @Published private(set) var validationIssues: [InkSampleValidationIssue] = []
    @Published private(set) var statusMessage: String?
    @Published var collectionMode: DatasetCollectionMode = .freeForm
    @Published private(set) var promptCorpus: InkPromptCorpus?
    @Published private(set) var selectedPromptID: String?
    @Published private(set) var anonymousSessionID = UUID().uuidString

    private let store: InkDatasetStore?
    private var undoSnapshots: [Data?] = []
    private var redoSnapshots: [Data?] = []

    init(datasetRootURL: URL? = nil) {
        let root = datasetRootURL ?? Self.defaultDatasetRootURL()
        do {
            store = try InkDatasetStore(rootURL: root)
            samples = try store?.loadAll() ?? []
            if let storedCorpus = try store?.loadPromptCorpus() {
                promptCorpus = storedCorpus
            } else {
                let foundationCorpus = InkPromptCorpus.foundationV1
                try store?.savePromptCorpus(foundationCorpus)
                promptCorpus = foundationCorpus
            }
            selectedPromptID = promptCorpus?.prompts.first?.id
            statusMessage = samples.isEmpty ? "Create a sample to begin collecting." : "Loaded \(samples.count) samples."
        } catch {
            // The UI remains usable as a draft editor while exposing the
            // failure; it never silently redirects a user dataset elsewhere.
            store = nil
            statusMessage = "Dataset storage could not be opened: \(error.localizedDescription)"
        }
    }

    var selectedSample: InkSample? {
        guard let selectedSampleID else { return nil }
        return samples.first { $0.id == selectedSampleID }
    }

    var canUndoDrawing: Bool { !undoSnapshots.isEmpty }
    var canRedoDrawing: Bool { !redoSnapshots.isEmpty }

    var activePrompt: InkPrompt? {
        guard let selectedPromptID else { return nil }
        return promptCorpus?.prompt(id: selectedPromptID)
    }

    var coverageStatistics: InkDatasetCoverageStatistics {
        InkDatasetAnalyzer.coverage(samples: samples, corpus: promptCorpus)
    }

    func createSample() {
        draftID = UUID()
        draftStrokes = []
        draftCanvas = InkCanvasMetadata(width: 1, height: 1, inputDevice: "Apple Pencil")
        rawLaTeX = ""
        canonicalLaTeX = nil
        mathInputLabel = nil
        drawingData = nil
        validationIssues = []
        undoSnapshots = []
        redoSnapshots = []
        statusMessage = "New sample draft."
    }

    func updateDrawing(_ drawing: PKDrawing, canvasSize: CGSize) {
        let nextData = drawing.dataRepresentation()
        guard nextData != drawingData else { return }
        undoSnapshots.append(drawingData)
        redoSnapshots.removeAll()
        applyDrawing(data: nextData, canvasSize: canvasSize)
    }

    func undoDrawing() {
        guard let previous = undoSnapshots.popLast() else { return }
        redoSnapshots.append(drawingData)
        applyDrawing(data: previous, canvasSize: CGSize(width: draftCanvas.width, height: draftCanvas.height))
    }

    func redoDrawing() {
        guard let next = redoSnapshots.popLast() else { return }
        undoSnapshots.append(drawingData)
        applyDrawing(data: next, canvasSize: CGSize(width: draftCanvas.width, height: draftCanvas.height))
    }

    /// Extension point for a future MathInput UI integration. DatasetCore keeps
    /// this opaque payload so it never becomes a second expression parser.
    func setMathInputCompatibleLabel(_ label: MathInputCompatibleExpression?) {
        mathInputLabel = label
    }

    /// Used by a host-owned canonicalization adapter. DatasetCore deliberately
    /// does not parse the raw LaTeX field to derive this value.
    func setCanonicalLaTeX(_ label: String?) {
        canonicalLaTeX = label
    }

    func advancePrompt() {
        guard let corpus = promptCorpus, !corpus.prompts.isEmpty else { return }
        let currentIndex = corpus.prompts.firstIndex { $0.id == selectedPromptID } ?? -1
        selectedPromptID = corpus.prompts[(currentIndex + 1) % corpus.prompts.count].id
        statusMessage = "Selected prompt \(activePrompt?.id ?? "")."
    }

    func validateDraft() {
        validationIssues = InkSampleValidator.validate(makeDraftSample(), corpus: promptCorpus)
        statusMessage = validationIssues.isEmpty ? "Draft is valid." : "Fix the reported validation issues before saving."
    }

    func saveDraft() {
        guard let store else {
            statusMessage = "Sample was not saved because dataset storage is unavailable."
            return
        }
        let sample = makeDraftSample()
        let issues = InkSampleValidator.validate(sample, corpus: promptCorpus)
        guard issues.isEmpty else {
            validationIssues = issues
            statusMessage = "Sample was not saved."
            return
        }
        do {
            try store.save(sample, corpus: promptCorpus)
            if let index = samples.firstIndex(where: { $0.id == sample.id }) {
                samples[index] = sample
            } else {
                samples.append(sample)
            }
            samples.sort { $0.metadata.createdAt < $1.metadata.createdAt }
            selectedSampleID = sample.id
            validationIssues = []
            statusMessage = "Saved \(sample.strokes.count) strokes as structured trace data."
        } catch {
            statusMessage = "Sample was not saved: \(error.localizedDescription)"
        }
    }

    func selectSample(id: UUID) {
        selectedSampleID = id
    }

    func exportDataset() {
        guard let store else {
            statusMessage = "Dataset export is unavailable because dataset storage could not be opened."
            return
        }
        do {
            let destination = Self.defaultExportRootURL()
            let assignments = InkWriterAwareSplitGenerator.makeAssignments(samples: samples)
            let exported = try store.exportDataset(
                samples: samples,
                to: destination,
                corpus: promptCorpus,
                splitAssignments: assignments
            )
            statusMessage = "Exported \(samples.count) samples to \(exported.lastPathComponent)."
        } catch {
            statusMessage = "Dataset export failed: \(error.localizedDescription)"
        }
    }

    private func makeDraftSample() -> InkSample {
        let prompted = collectionMode == .prompted ? activePrompt : nil
        let provenance = InkSampleProvenance(
            promptID: prompted?.id,
            corpusVersion: prompted?.corpusVersion,
            anonymousWriterID: anonymousSessionID,
            inputDeviceCategory: .applePencil,
            orientation: orientation(for: draftCanvas),
            collectionTimestamp: Date()
        )
        InkSample(
            id: draftID,
            strokes: draftStrokes,
            canvas: draftCanvas,
            label: .init(
                rawLaTeX: rawLaTeX,
                canonicalLaTeX: prompted?.expectedCanonicalLaTeX ?? canonicalLaTeX,
                mathInput: mathInputLabel
            ),
            metadata: .init(provenance: provenance)
        )
    }

    private func applyDrawing(data: Data?, canvasSize: CGSize) {
        drawingData = data
        let drawing = DatasetInkDrawingAdapter.drawing(from: data)
        draftStrokes = DatasetInkDrawingAdapter.strokes(from: drawing)
        let width = max(Double(canvasSize.width), 1)
        let height = max(Double(canvasSize.height), 1)
        draftCanvas = InkCanvasMetadata(width: width, height: height, inputDevice: "Apple Pencil")
        validationIssues = []
    }

    private static func defaultDatasetRootURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("OpenMathInkCollector", isDirectory: true)
    }

    private func orientation(for canvas: InkCanvasMetadata) -> InkCanvasOrientation {
        guard canvas.width > 0, canvas.height > 0 else { return .unknown }
        if canvas.width == canvas.height { return .square }
        return canvas.width > canvas.height ? .landscape : .portrait
    }

    private static func defaultExportRootURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("OpenMathInkExports", isDirectory: true)
    }
}
