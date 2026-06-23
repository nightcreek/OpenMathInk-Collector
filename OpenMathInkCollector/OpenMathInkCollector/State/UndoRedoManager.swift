import Foundation
import PencilKit
import EMathicaMathInputCore

/// 操作历史记录，用于撤销/重做
enum WorkspaceAction: Equatable {
    case latexInput(String)
    case drawingChange(DrawingSnapshot)
    case statusChange(SampleStatus)

    static func == (lhs: WorkspaceAction, rhs: WorkspaceAction) -> Bool {
        switch (lhs, rhs) {
        case let (.latexInput(l1), .latexInput(l2)):
            return l1 == l2
        case let (.drawingChange(d1), .drawingChange(d2)):
            return d1.data == d2.data && d1.size == d2.size
        case let (.statusChange(s1), .statusChange(s2)):
            return s1 == s2
        default:
            return false
        }
    }
}

/// 手绘数据快照
struct DrawingSnapshot: Equatable {
    let data: Data?
    let size: CGSize

    init(data: Data?, size: CGSize) {
        self.data = data
        self.size = size
    }

    init(drawing: PKDrawing, size: CGSize) {
        self.data = drawing.dataRepresentation()
        self.size = size
    }
}

/// 撤销/重做历史管理器
@MainActor
final class UndoRedoManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var undoStack: [UndoState] = []
    private var redoStack: [UndoState] = []
    private let maxHistorySize: Int

    struct UndoState: Equatable {
        let action: WorkspaceAction
        let latex: String
        let sourceText: String
        let computeExpression: String
        let drawingSnapshot: DrawingSnapshot
        let timestamp: Date
    }

    init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
    }

    /// 记录当前状态到撤销栈
    func record(
        action: WorkspaceAction,
        latex: String,
        sourceText: String,
        computeExpression: String,
        drawing: PKDrawing?,
        canvasSize: CGSize
    ) {
        let snapshot = drawing.map { DrawingSnapshot(drawing: $0, size: canvasSize) }
            ?? DrawingSnapshot(data: nil, size: canvasSize)

        let state = UndoState(
            action: action,
            latex: latex,
            sourceText: sourceText,
            computeExpression: computeExpression,
            drawingSnapshot: snapshot,
            timestamp: Date()
        )

        // 避免重复记录相同状态
        if let last = undoStack.last, last == state {
            return
        }

        undoStack.append(state)
        redoStack.removeAll()

        // 限制历史大小
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        updateCanUndoRedo()
    }

    /// 弹出撤销栈并返回状态
    func popUndo() -> UndoState? {
        guard let state = undoStack.popLast() else { return nil }
        updateCanUndoRedo()
        return state
    }

    /// 压入重做栈
    func pushRedo(_ state: UndoState) {
        redoStack.append(state)
        updateCanUndoRedo()
    }

    /// 弹出重做栈并返回状态
    func popRedo() -> UndoState? {
        guard let state = redoStack.popLast() else { return nil }
        updateCanUndoRedo()
        return state
    }

    /// 压入撤销栈（用于重做时）
    func pushUndo(_ state: UndoState) {
        undoStack.append(state)
        updateCanUndoRedo()
    }

    /// 清空所有历史
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
    }

    /// 获取撤销栈大小
    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }

    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
