import SwiftUI

/// LaTeX 到 Unicode 符号的替换映射（按长度降序排列避免冲突）
let latexSymbolReplacements: [(String, String)] = [
    ("\\left", ""), ("\\right", ""),
    ("\\times", "×"), ("\\div", "÷"),
    ("\\le", "≤"), ("\\ge", "≥"), ("\\ne", "≠"),
    ("\\alpha", "α"), ("\\beta", "β"), ("\\theta", "θ"),
    ("\\lambda", "λ"), ("\\pi", "π"), ("\\infty", "∞"),
    ("\\pm", "±"), ("\\partial", "∂"),
    ("\\in", "∈"), ("\\notin", "∉"),
    ("\\cap", "∩"), ("\\cup", "∪"), ("\\emptyset", "∅"),
    ("\\sum", "Σ"), ("\\int", "∫"),
    ("\\frac", ""), ("\\sqrt", "√"),
    ("{", ""), ("}", ""), ("\\", "")
]

struct FormulaLabelPreviewView: View {
    let text: String
    let emptyText: String
    var fontSize: CGFloat = 28
    var showsTemporaryCaption: Bool = false
    var showsCaret: Bool = false
    
    @ObservedObject private var renderManager = RenderServiceManager.shared
    @State private var cachedText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .font(.system(size: fontSize))
            } else {
                if let result = renderManager.lastRenderResult, result.displayText == text {
                    renderResultView(result)
                } else {
                    Text(formattedPreview(text) + (showsCaret ? "|" : ""))
                        .font(.system(size: fontSize, weight: .medium, design: .serif))
                        .textSelection(.enabled)
                }
            }
            
            if showsTemporaryCaption {
                Text("临时文本预览")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(3)
        .onChange(of: text) { newText in
            if newText != cachedText {
                cachedText = newText
                Task {
                    await renderManager.render(newText, fontSize: fontSize)
                }
            }
        }
        .onAppear {
            if !text.isEmpty && cachedText != text {
                cachedText = text
                Task {
                    await renderManager.render(text, fontSize: fontSize)
                }
            }
        }
    }
    
    private func renderResultView(_ result: LatexRenderResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let image = result.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 100)
            } else {
                Text(result.displayText + (showsCaret ? "|" : ""))
                    .font(.system(size: fontSize, weight: .medium, design: .serif))
                    .textSelection(.enabled)
            }
            
            if result.hasError, let error = result.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func formattedPreview(_ raw: String) -> String {
        var value = raw
        for (from, to) in latexSymbolReplacements {
            value = value.replacingOccurrences(of: from, with: to)
        }
        return value
    }
}
