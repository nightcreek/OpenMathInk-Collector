import Foundation
import EMathicaMathInputCore

struct MathKeyboardKey: Identifiable, Hashable {
    enum Tab: String, CaseIterable, Identifiable {
        case numeric = "123"
        case function = "f(x)"
        case alphabet = "ABC"
        case symbols = "符号"

        var id: String { rawValue }
    }

    enum ActionPayload: Hashable {
        case single(KeyboardAction)
        case sequence([KeyboardAction])
    }

    enum Subgroup: String, CaseIterable, Identifiable {
        case common = "常用"
        case latinLower = "小写"
        case latinUpper = "大写"
        case greekLower = "Greek"
        case greekUpper = "Greek Caps"
        case logic = "逻辑"
        case set = "集合"
        case special = "特殊"
        case templates = "模板"

        var id: String { rawValue }
    }

    let id = UUID()
    let title: String
    let subtitle: String?
    let action: ActionPayload
    let tab: Tab
    let subgroup: Subgroup?
    let isAccent: Bool
    let isEnabled: Bool
}
