import Foundation
import Combine

/// `MathInputSession` 封装器
///
/// 注意：`MathInputSession` 是引用类型（class），其属性变更不会自动触发 `@Published` 的
/// `objectWillChange` 通知。因此每个修改 session 状态的操作都需要手动调用
/// `objectWillChange.send()` 来通知 SwiftUI 刷新视图。
/// 这是已知的设计权衡，因为无法修改外部包的实现。
class CollectorMathInputState: ObservableObject {
    @Published private(set) var session: MathInputSession

    init() {
        self.session = MathInputSession()
    }

    func apply(_ action: MathInputAction) {
        session.apply(action)
        // 注意：MathInputSession 是 class，引用不变时 @Published 不会触发通知
        objectWillChange.send()
    }

    func reset() {
        session.reset()
        objectWillChange.send()
    }

    func exportASTJSON() -> Data? {
        session.exportASTJSON()
    }

    func importASTJSON(from data: Data) -> Bool {
        let result = session.importASTJSON(from: data)
        objectWillChange.send()
        return result
    }

    func convertToMathFormat() -> String? {
        session.convertToMathFormat()
    }

    func convertToLaTeX() -> String? {
        session.convertToLaTeX()
    }
}
