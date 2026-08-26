import OpenMathInkDatasetCore
import SwiftUI

struct DatasetCollectorRootView: View {
    @StateObject private var workspace = DatasetCollectorWorkspaceState()

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { workspace.selectedSampleID },
                set: { if let id = $0 { workspace.selectSample(id: id) } }
            )) {
                Section("Dataset Samples") {
                    ForEach(workspace.samples) { sample in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sample.label.rawLaTeX.isEmpty ? "Unlabelled sample" : sample.label.rawLaTeX)
                                .lineLimit(1)
                            Text("\(sample.strokes.count) strokes · \(sample.id.uuidString.prefix(8))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(sample.id)
                    }
                }
            }
            .navigationTitle("OpenMathInk")
            .toolbar {
                Button(action: workspace.createSample) {
                    Label("New Sample", systemImage: "plus")
                }
            }
        } detail: {
            HStack(spacing: 0) {
                editor
                Divider()
                inspector
                    .frame(minWidth: 280, idealWidth: 320)
            }
            .navigationTitle("Handwriting Collector")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: workspace.undoDrawing) {
                        Label("Undo Drawing", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!workspace.canUndoDrawing)
                    Button(action: workspace.redoDrawing) {
                        Label("Redo Drawing", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!workspace.canRedoDrawing)
                    Button("Validate", action: workspace.validateDraft)
                    Button("Save", action: workspace.saveDraft)
                    Button("Export", action: workspace.exportDataset)
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Draw one mathematical expression")
                .font(.headline)
            DatasetPencilCanvasView(drawingData: $workspace.drawingData) { drawing, size in
                workspace.updateDrawing(drawing, canvasSize: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
            .padding(.bottom, 4)
            HStack {
                Text("\(workspace.draftStrokes.count) strokes")
                Spacer()
                Text("\(workspace.draftStrokes.reduce(0) { $0 + $1.points.count }) points")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Collection Mode")
                    .font(.headline)
                Picker("Collection Mode", selection: $workspace.collectionMode) {
                    ForEach(DatasetCollectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if workspace.collectionMode == .prompted {
                    promptCard
                }

                Text("Label")
                    .font(.headline)
                TextField("Raw LaTeX, e.g. x^2 + y^2", text: $workspace.rawLaTeX, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                Text("Raw LaTeX is stored as text. A future MathInput screen may attach an opaque AST label through DatasetCore; this screen does not parse expressions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = workspace.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !workspace.validationIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Validation")
                            .font(.headline)
                        ForEach(workspace.validationIssues) { issue in
                            Text("• \(issue.message)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let selected = workspace.selectedSample {
                    Divider()
                    Text("Saved Sample Review")
                        .font(.headline)
                    LabeledContent("Raw LaTeX") {
                        Text(selected.label.rawLaTeX.isEmpty ? "—" : selected.label.rawLaTeX)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.caption)
                    DatasetInkReviewView(sample: selected)
                        .frame(height: 180)
                    Text("\(selected.strokes.count) strokes · \(selected.boundingBox.map { "\($0.maxX - $0.minX) × \($0.maxY - $0.minY)" } ?? "no bounds")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                coverageCard
            }
            .padding()
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Target Expression")
                    .font(.headline)
                Spacer()
                Button("Next", action: workspace.advancePrompt)
            }
            if let prompt = workspace.activePrompt {
                Text(prompt.expectedCanonicalLaTeX)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Text("\(prompt.category.rawValue) · difficulty \(prompt.difficulty)/5 · \(prompt.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No prompt corpus is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var coverageCard: some View {
        let statistics = workspace.coverageStatistics
        return VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Dataset Coverage")
                .font(.headline)
            Text("\(workspace.samples.count) samples · \(statistics.promptCoverage.filter { $0.sampleCount > 0 }.count)/\(statistics.promptCoverage.count) prompts covered")
                .font(.caption)
            if !statistics.underrepresentedCategories.isEmpty {
                Text("Not yet represented: \(statistics.underrepresentedCategories.map(\.rawValue).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
