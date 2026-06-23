import SwiftUI
import EMathicaMathInputCore

struct LatexKeyboardInputView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState

    private var keys: [MathKeyboardKey] {
        numericKeys + functionKeys + alphabetKeys + symbolKeys
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("数学键盘")
                        .font(.title3.weight(.semibold))
                    Text("按分类录入结构化公式标签，避免直接输入原始 LaTeX 指令。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusText
            }

            MathKeyboardView(keys: keys) { key in
                applyPayload(key.action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusText: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(workspace.currentLatex.isEmpty ? "未录入标签" : "已录入标签")
                .font(.caption.weight(.semibold))
                .foregroundStyle(workspace.currentLatex.isEmpty ? Color.secondary : Color.green)
            Text(workspace.currentLatex.isEmpty ? "开始输入" : "继续编辑")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func applyPayload(_ payload: MathKeyboardKey.ActionPayload) {
        switch payload {
        case .single(let action):
            workspace.applyKeyboardAction(action)
        case .sequence(let actions):
            for action in actions {
                workspace.applyKeyboardAction(action)
            }
        }
    }

    private func key(
        _ title: String,
        _ action: MathKeyboardKey.ActionPayload,
        tab: MathKeyboardKey.Tab,
        subgroup: MathKeyboardKey.Subgroup? = nil,
        subtitle: String? = nil,
        accent: Bool = false,
        enabled: Bool = true
    ) -> MathKeyboardKey {
        MathKeyboardKey(
            title: title,
            subtitle: subtitle,
            action: action,
            tab: tab,
            subgroup: subgroup,
            isAccent: accent,
            isEnabled: enabled
        )
    }

    private var numericKeys: [MathKeyboardKey] {
        [
            key("7", .single(.insertCharacter("7")), tab: .numeric),
            key("8", .single(.insertCharacter("8")), tab: .numeric),
            key("9", .single(.insertCharacter("9")), tab: .numeric),
            key("×", .single(.insertSymbol("\\times")), tab: .numeric),
            key("÷", .single(.insertSymbol("\\div")), tab: .numeric),
            key("4", .single(.insertCharacter("4")), tab: .numeric),
            key("5", .single(.insertCharacter("5")), tab: .numeric),
            key("6", .single(.insertCharacter("6")), tab: .numeric),
            key("+", .single(.insertOperator("+")), tab: .numeric),
            key("-", .single(.insertOperator("-")), tab: .numeric),
            key("1", .single(.insertCharacter("1")), tab: .numeric),
            key("2", .single(.insertCharacter("2")), tab: .numeric),
            key("3", .single(.insertCharacter("3")), tab: .numeric),
            key("=", .single(.insertOperator("=")), tab: .numeric, accent: true),
            key("0", .single(.insertCharacter("0")), tab: .numeric),
            key(".", .single(.insertCharacter(".")), tab: .numeric),
            key("x", .single(.insertCharacter("x")), tab: .numeric),
            key("y", .single(.insertCharacter("y")), tab: .numeric),
            key("π", .single(.insertSymbol("\\pi")), tab: .numeric),
            key("e", .single(.insertCharacter("e")), tab: .numeric),
            key("<", .single(.insertOperator("<")), tab: .numeric),
            key(">", .single(.insertOperator(">")), tab: .numeric),
            key("≤", .single(.insertSymbol("\\le")), tab: .numeric),
            key("≥", .single(.insertSymbol("\\ge")), tab: .numeric),
            key("≠", .single(.insertSymbol("\\ne")), tab: .numeric),
            key("←", .single(.moveLeft), tab: .numeric),
            key("→", .single(.moveRight), tab: .numeric),
            key("⌫", .single(.backspace), tab: .numeric),
            key("回车", .single(.enter), tab: .numeric, accent: true)
        ]
    }

    private var functionKeys: [MathKeyboardKey] {
        [
            key("sin", .single(.insertFunction("sin")), tab: .function),
            key("cos", .single(.insertFunction("cos")), tab: .function),
            key("tan", .single(.insertFunction("tan")), tab: .function),
            key("log", .single(.insertFunction("log")), tab: .function),
            key("ln", .single(.insertFunction("ln")), tab: .function),
            key("exp", .single(.insertFunction("exp")), tab: .function),
            key("f(x)", .sequence([.insertCharacter("f"), .insertTemplate(.parentheses)]), tab: .function),
            key("lim", .single(.insertTemplate(.limit)), tab: .function),
            key("Σ", .single(.insertTemplate(.sum)), tab: .function),
            key("∫", .single(.insertTemplate(.integral)), tab: .function),
            key("∂", .single(.insertCharacter("∂")), tab: .function),
            key("分数", .single(.insertTemplate(.fraction)), tab: .function),
            key("x²", .sequence([.insertTemplate(.superscript), .insertCharacter("2")]), tab: .function),
            key("xʸ", .single(.insertTemplate(.superscript)), tab: .function),
            key("下标", .single(.insertTemplate(.subscriptTemplate)), tab: .function),
            key("√□", .single(.insertTemplate(.sqrt)), tab: .function),
            key("|□|", .single(.insertTemplate(.absoluteValue)), tab: .function),
            key("(□)", .single(.insertTemplate(.parentheses)), tab: .function),
            key("[□]", .single(.insertTemplate(.brackets)), tab: .function),
            key("{□}", .single(.insertTemplate(.braces)), tab: .function)
        ]
    }

    private var alphabetKeys: [MathKeyboardKey] {
        let common = ["x","y","z","t","n","m","k","a","b","c","u","v","w"]
        let latinLower = "abcdefghijklmnopqrstuvwxyz".map { String($0) }
        let latinUpper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }
        let greekLower = ["α","β","γ","δ","ε","ζ","η","θ","ι","κ","λ","μ","ν","ξ","π","ρ","σ","τ","φ","χ","ψ","ω"]
        let greekUpper = ["Γ","Δ","Θ","Λ","Ξ","Π","Σ","Φ","Ψ","Ω"]

        let commonKeys = common.map { key($0, .single(.insertCharacter($0)), tab: .alphabet, subgroup: .common) }
        let lowerKeys = latinLower.map { key($0, .single(.insertCharacter($0)), tab: .alphabet, subgroup: .latinLower) }
        let upperKeys = latinUpper.map { key($0, .single(.insertCharacter($0)), tab: .alphabet, subgroup: .latinUpper) }
        let greekLowerKeys = greekLower.map { key($0, .single(.insertCharacter($0)), tab: .alphabet, subgroup: .greekLower) }
        let greekUpperKeys = greekUpper.map { key($0, .single(.insertCharacter($0)), tab: .alphabet, subgroup: .greekUpper) }
        return commonKeys + lowerKeys + upperKeys + greekLowerKeys + greekUpperKeys
    }

    private var symbolKeys: [MathKeyboardKey] {
        [
            key("∧", .single(.insertCharacter("∧")), tab: .symbols, subgroup: .logic),
            key("∨", .single(.insertCharacter("∨")), tab: .symbols, subgroup: .logic),
            key("¬", .single(.insertCharacter("¬")), tab: .symbols, subgroup: .logic),
            key("⇒", .single(.insertCharacter("⇒")), tab: .symbols, subgroup: .logic),
            key("⇔", .single(.insertCharacter("⇔")), tab: .symbols, subgroup: .logic),
            key("∀", .single(.insertCharacter("∀")), tab: .symbols, subgroup: .logic),
            key("∃", .single(.insertCharacter("∃")), tab: .symbols, subgroup: .logic),

            key("∈", .single(.insertCharacter("∈")), tab: .symbols, subgroup: .set),
            key("∉", .single(.insertCharacter("∉")), tab: .symbols, subgroup: .set),
            key("⊂", .single(.insertCharacter("⊂")), tab: .symbols, subgroup: .set),
            key("⊆", .single(.insertCharacter("⊆")), tab: .symbols, subgroup: .set),
            key("∪", .single(.insertCharacter("∪")), tab: .symbols, subgroup: .set),
            key("∩", .single(.insertCharacter("∩")), tab: .symbols, subgroup: .set),
            key("∅", .single(.insertCharacter("∅")), tab: .symbols, subgroup: .set),

            key("≈", .single(.insertCharacter("≈")), tab: .symbols, subgroup: .special),
            key("∝", .single(.insertCharacter("∝")), tab: .symbols, subgroup: .special),
            key("∞", .single(.insertCharacter("∞")), tab: .symbols, subgroup: .special),
            key("±", .single(.insertCharacter("±")), tab: .symbols, subgroup: .special),

            key("矩阵2×2", .single(.insertTemplate(.matrix(rows: 2, cols: 2))), tab: .symbols, subgroup: .templates),
            key("矩阵3×3", .single(.insertTemplate(.matrix(rows: 3, cols: 3))), tab: .symbols, subgroup: .templates),
            key("分段函数", .single(.insertTemplate(.piecewise(rows: 2))), tab: .symbols, subgroup: .templates),
            key("方程组", .single(.insertTemplate(.cases(rows: 2))), tab: .symbols, subgroup: .templates)
        ]
    }
}
