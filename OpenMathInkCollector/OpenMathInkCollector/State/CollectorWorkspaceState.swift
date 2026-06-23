import Foundation
import Combine
import CoreGraphics
import PencilKit
import EMathicaMathInputCore

@MainActor
final class CollectorWorkspaceState: ObservableObject {
    @Published var samples: [MathInkSample] = []
    @Published var selectedSampleID: UUID?
    @Published var currentLatex: String = ""
    @Published var currentSourceText: String = ""
    @Published var currentComputeExpression: String = ""
    @Published var currentDrawingData: Data?
    @Published var currentCanvasSize: CGSize = CGSize(width: 1024, height: 512)
    @Published var filter: SampleStatus?
    @Published var exportedPackageURL: URL?
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    
    // 导出进度
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatusMessage: String = ""
    
    // 撤销/重做
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    // 删除确认
    @Published var showDeleteConfirmation: Bool = false
    @Published var sampleToDelete: UUID?
    
    private let store: LocalSampleStore
    private let mathInputState = CollectorMathInputState()
    private let undoRedoManager = UndoRedoManager()
    
    // 订阅 undo/redo 状态变化
    private var cancellables = Set<AnyCancellable>()
    
    init(store: LocalSampleStore = LocalSampleStore()) {
        self.store = store
        
        // 延迟加载样本，避免在 init 中阻塞主线程
        Task { @MainActor in
            let loaded = try? self.store.loadSamples()
            let initialSamples = loaded ?? []
            self.samples = initialSamples
            if initialSamples.isEmpty {
                self.createNewSample()
            } else if let first = initialSamples.first {
                self.selectSample(id: first.id)
            }
        }
        
        // 监听撤销/重做状态
        undoRedoManager.$canUndo
            .receive(on: DispatchQueue.main)
            .assign(to: &$canUndo)
        undoRedoManager.$canRedo
            .receive(on: DispatchQueue.main)
            .assign(to: &$canRedo)
    }
    
    var selectedSample: MathInkSample? {
        guard let selectedSampleID else { return nil }
        return samples.first(where: { $0.id == selectedSampleID })
    }
    
    var filteredSamples: [MathInkSample] {
        let sorted = samples.sorted { $0.modifiedAt > $1.modifiedAt }
        guard let filter else { return sorted }
        return sorted.filter { $0.status == filter }
    }
    
    var hasFormulaLabel: Bool {
        !currentLatex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasHandwriting: Bool {
        guard
            let data = currentDrawingData,
            let drawing = try? PKDrawing(data: data)
        else { return false }
        return !drawing.strokes.isEmpty
    }
    
    // MARK: - 撤销/重做
    
    /// 记录当前状态用于撤销
    func recordUndoState(action: WorkspaceAction) {
        let drawing = currentDrawingData.flatMap { try? PKDrawing(data: $0) }
        undoRedoManager.record(
            action: action,
            latex: currentLatex,
            sourceText: currentSourceText,
            computeExpression: currentComputeExpression,
            drawing: drawing,
            canvasSize: currentCanvasSize
        )
    }
    
    /// 执行撤销
    func undo() {
        guard let state = undoRedoManager.popUndo() else { return }
        pushCurrentToRedo()
        restoreState(state)
        infoMessage = "已撤销"
    }
    
    /// 执行重做
    func redo() {
        guard let state = undoRedoManager.popRedo() else { return }
        pushCurrentToUndo()
        restoreState(state)
        infoMessage = "已重做"
    }
    
    private func pushCurrentToUndo() {
        let drawing = currentDrawingData.flatMap { try? PKDrawing(data: $0) }
        undoRedoManager.pushUndo(UndoRedoManager.UndoState(
            action: .latexInput(currentLatex),
            latex: currentLatex,
            sourceText: currentSourceText,
            computeExpression: currentComputeExpression,
            drawingSnapshot: DrawingSnapshot(drawing: drawing, size: currentCanvasSize),
            timestamp: Date()
        ))
    }
    
    private func pushCurrentToRedo() {
        let drawing = currentDrawingData.flatMap { try? PKDrawing(data: $0) }
        undoRedoManager.pushRedo(UndoRedoManager.UndoState(
            action: .latexInput(currentLatex),
            latex: currentLatex,
            sourceText: currentSourceText,
            computeExpression: currentComputeExpression,
            drawingSnapshot: DrawingSnapshot(drawing: drawing, size: currentCanvasSize),
            timestamp: Date()
        ))
    }
    
    private func restoreState(_ state: UndoRedoManager.UndoState) {
        currentLatex = state.latex
        currentSourceText = state.sourceText
        currentComputeExpression = state.computeExpression
        currentDrawingData = state.drawingSnapshot.data
        currentCanvasSize = state.drawingSnapshot.size
        
        // 恢复 AST 状态
        if !state.sourceText.isEmpty {
            mathInputState.reset()
            replayPlainTextInput(state.sourceText)
        }
        
        // 更新样本
        if var sample = selectedSample {
            sample.latex = currentLatex
            sample.sourceText = currentSourceText
            sample.computeExpression = currentComputeExpression
            sample.modifiedAt = Date()
            upsert(sample)
            persistSamples()
        }
    }
    
    // MARK: - 样本操作
    
    func createNewSample() {
        recordUndoState(action: .latexInput("new_sample"))
        
        let now = Date()
        let sample = MathInkSample(
            id: UUID(),
            latex: "",
            sourceText: "",
            computeExpression: "",
            astJSONFileName: nil,
            status: .draft,
            drawingDataFileName: nil,
            imageFileName: nil,
            canvasWidth: currentCanvasSize.width,
            canvasHeight: currentCanvasSize.height,
            createdAt: now,
            modifiedAt: now
        )
        samples.append(sample)
        selectedSampleID = sample.id
        mathInputState.reset()
        syncDerivedInputStrings()
        currentDrawingData = nil
        persistSamples()
    }
    
    func applyKeyboardAction(_ action: KeyboardAction) {
        // 记录撤销状态（仅在有实质变化时）
        if !currentLatex.isEmpty || !currentSourceText.isEmpty {
            recordUndoState(action: .latexInput(currentLatex))
        }
        
        mathInputState.apply(action)
        syncDerivedInputStrings()
        
        guard var sample = selectedSample else { return }
        sample.latex = currentLatex
        sample.sourceText = currentSourceText
        sample.computeExpression = currentComputeExpression
        sample.modifiedAt = Date()
        upsert(sample)
    }
    
    func clearFormulaInput() {
        if !currentLatex.isEmpty {
            recordUndoState(action: .latexInput(currentLatex))
        }
        
        mathInputState.reset()
        syncDerivedInputStrings()
        
        guard var sample = selectedSample else { return }
        sample.latex = currentLatex
        sample.sourceText = currentSourceText
        sample.computeExpression = currentComputeExpression
        sample.modifiedAt = Date()
        upsert(sample)
    }
    
    func updateCurrentDrawing(_ drawing: PKDrawing, canvasSize: CGSize) {
        // 记录撤销状态
        if hasHandwriting {
            recordUndoState(action: .drawingChange(DrawingSnapshot(drawing: drawing, size: canvasSize)))
        }
        
        currentCanvasSize = canvasSize
        currentDrawingData = drawing.dataRepresentation()
    }
    
    func saveCurrentDraft() {
        guard var sample = selectedSample else { return }
        
        // 记录撤销状态
        recordUndoState(action: .drawingChange(DrawingSnapshot(
            data: currentDrawingData,
            size: currentCanvasSize
        )))
        
        let drawing: PKDrawing
        if let data = currentDrawingData, let parsed = try? PKDrawing(data: data) {
            drawing = parsed
        } else {
            drawing = PKDrawing()
        }
        
        do {
            let artifact = try store.saveDrawing(drawing, sampleID: sample.id, canvasSize: currentCanvasSize)
            sample.latex = currentLatex
            sample.sourceText = currentSourceText
            sample.computeExpression = currentComputeExpression
            let astData = try mathInputState.exportASTJSON()
            sample.astJSONFileName = try store.saveASTJSON(astData, for: sample.id)
            sample.drawingDataFileName = artifact.drawingFileName
            sample.imageFileName = artifact.imageFileName
            sample.canvasWidth = currentCanvasSize.width
            sample.canvasHeight = currentCanvasSize.height
            sample.modifiedAt = Date()
            if sample.status == .exported { sample.status = .draft }
            try store.saveSampleMetadataJSON(sample)
            upsert(sample)
            persistSamples()
            infoMessage = "草稿已保存"
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    func confirmCurrentSample() {
        if !hasHandwriting || !hasFormulaLabel {
            errorMessage = "请先完成手写内容和公式标签的录入"
            return
        }
        
        recordUndoState(action: .statusChange(.confirmed))
        saveCurrentDraft()
        
        guard var sample = selectedSample else { return }
        sample.latex = currentLatex
        sample.sourceText = currentSourceText
        sample.computeExpression = currentComputeExpression
        sample.status = .confirmed
        sample.modifiedAt = Date()
        upsert(sample)
        persistSamples()
        infoMessage = "样本已确认"
    }
    
    // MARK: - 删除确认
    
    func requestDeleteSample(id: UUID) {
        sampleToDelete = id
        showDeleteConfirmation = true
    }
    
    func confirmDelete() {
        guard let id = sampleToDelete else { return }
        performDelete(id: id)
        sampleToDelete = nil
        showDeleteConfirmation = false
    }
    
    func cancelDelete() {
        sampleToDelete = nil
        showDeleteConfirmation = false
    }
    
    private func performDelete(id: UUID) {
        guard let index = samples.firstIndex(where: { $0.id == id }) else { return }
        
        recordUndoState(action: .statusChange(.draft))
        
        let target = samples[index]
        store.deleteSampleArtifacts(target)
        samples.remove(at: index)
        
        if selectedSampleID == id {
            if let first = samples.first {
                selectSample(id: first.id)
            } else {
                createNewSample()
            }
        }
        persistSamples()
        infoMessage = "样本已删除"
    }
    
    func deleteSample(id: UUID) {
        performDelete(id: id)
    }
    
    func selectSample(id: UUID) {
        selectedSampleID = id
        guard let sample = samples.first(where: { $0.id == id }) else { return }
        
        if let astFileName = sample.astJSONFileName,
           let data = try? store.loadASTJSON(fileName: astFileName) {
            try? mathInputState.importASTJSON(data)
        } else {
            mathInputState.reset()
            if !sample.sourceText.isEmpty {
                replayPlainTextInput(sample.sourceText)
            } else if !sample.latex.isEmpty {
                replayPlainTextInput(sample.latex)
            }
        }
        syncDerivedInputStrings()
        currentDrawingData = store.loadDrawingData(fileName: sample.drawingDataFileName)
        currentCanvasSize = CGSize(width: max(sample.canvasWidth, 300), height: max(sample.canvasHeight, 200))
        
        // 清空撤销历史（切换样本时）
        undoRedoManager.clearHistory()
    }
    
    func clearCurrentDrawing() {
        if hasHandwriting {
            recordUndoState(action: .drawingChange(DrawingSnapshot(data: currentDrawingData, size: currentCanvasSize)))
        }
        currentDrawingData = PKDrawing().dataRepresentation()
    }
    
    // MARK: - 异步导出
    
    func exportConfirmedSamples() {
        let confirmed = samples.filter { $0.status == .confirmed }
        exportSamples(samples: confirmed)
    }
    
    func exportSamples(samples: [MathInkSample]) {
        guard !samples.isEmpty else {
            errorMessage = "没有可导出的样本"
            return
        }
        
        // 检查贡献者同意
        guard ContributorConsentManager.shared.hasValidConsent else {
            errorMessage = "请先同意数据贡献条款"
            return
        }
        
        isExporting = true
        exportProgress = 0.0
        exportStatusMessage = "正在准备导出..."
        
        let exportIDs = samples.filter { $0.status == .confirmed }.map(\.id)
        
        Task {
            do {
                let packageURL = try await performExport(samples: samples)
                
                await MainActor.run {
                    exportedPackageURL = packageURL
                    exportProgress = 1.0
                    exportStatusMessage = "导出完成"
                    isExporting = false
                    
                    for id in exportIDs {
                        if let idx = samples.firstIndex(where: { $0.id == id }) {
                            samples[idx].status = .exported
                            samples[idx].modifiedAt = Date()
                        }
                    }
                    persistSamples()
                    infoMessage = "导出完成，共 \(exportIDs.count) 条样本"
                }
            } catch {
                await MainActor.run {
                    errorMessage = "导出失败: \(error.localizedDescription)"
                    isExporting = false
                    exportStatusMessage = ""
                }
            }
        }
    }
    
    private func performExport(samples confirmed: [MathInkSample]) async throws -> URL {
        let exportRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMathInkExports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)

        guard let consent = ContributorConsentManager.shared.currentConsent else {
            throw ExportError.missingConsent
        }

        exportStatusMessage = "正在复制样本文件..."

        let builder = DatasetPackageBuilder()
        let result = try await Task.detached(priority: .userInitiated) {
            try builder.buildPackage(
                samples: confirmed,
                store: self.store,
                targetDirectory: exportRoot,
                consent: consent
            )
        }.value

        exportProgress = 1.0
        exportStatusMessage = "正在完成..."

        return result
    }
    
    func imageURL(for sample: MathInkSample) -> URL? {
        store.imageURL(fileName: sample.imageFileName)
    }
    
    private func upsert(_ sample: MathInkSample) {
        if let idx = samples.firstIndex(where: { $0.id == sample.id }) {
            samples[idx] = sample
        } else {
            samples.append(sample)
        }
    }
    
    private func loadSamples() {
        do {
            samples = try store.loadSamples()
        } catch {
            errorMessage = "读取样本失败: \(error.localizedDescription)"
            samples = []
        }
    }
    
    private func persistSamples() {
        do {
            try store.persistSampleIndex(samples)
        } catch {
            errorMessage = "写入样本索引失败: \(error.localizedDescription)"
        }
    }
    
    private func syncDerivedInputStrings() {
        currentLatex = mathInputState.latex
        currentSourceText = mathInputState.sourceText
        currentComputeExpression = mathInputState.computeExpression
    }
    
    private func replayPlainTextInput(_ text: String) {
        for character in text {
            mathInputState.apply(.insertCharacter(String(character)))
        }
    }
    
    // MARK: - 统计与清理
    
    struct StorageUsage {
        let totalFiles: Int
        let storageSize: Int
    }
    
    func getStorageUsage() async -> StorageUsage {
        var totalFiles = 0
        var totalSize = 0
        let fileManager = FileManager.default
        
        let directories = [
            store.storageRoot,
            store.drawingsRoot,
            store.imagesRoot,
            store.astRoot
        ]
        
        for dir in directories {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let url as URL in enumerator {
                guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true
                else { continue }
                totalFiles += 1
                if let size = resourceValues.fileSize {
                    totalSize += size
                }
            }
        }
        
        return StorageUsage(totalFiles: totalFiles, storageSize: totalSize)
    }
    
    func cleanupOrphanedFiles() async throws {
        try store.cleanupOrphanedFiles()
    }
}

enum ExportError: LocalizedError {
    case missingConsent

    var errorDescription: String? {
        switch self {
        case .missingConsent:
            return "请先同意数据贡献条款"
        }
    }
}
