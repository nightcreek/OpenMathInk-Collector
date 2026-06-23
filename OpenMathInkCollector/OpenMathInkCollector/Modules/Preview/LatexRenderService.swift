import Foundation
import SwiftUI
import EMathicaMathInputCore

/// LaTeX渲染服务协议
protocol LatexRenderService {
    func render(_ latex: String, fontSize: CGFloat) async throws -> LatexRenderResult
}

/// 渲染结果
struct LatexRenderResult {
    var image: Image?
    var displayText: String
    var hasError: Bool
    var errorMessage: String?
    var size: CGSize?
}

/// 使用 eMathica 的 MathRenderer 进行渲染
class EMathicaMathRenderService: LatexRenderService {
    private let renderer: MathRenderer
    
    init() {
        renderer = MathRenderer()
    }
    
    func render(_ latex: String, fontSize: CGFloat) async throws -> LatexRenderResult {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return LatexRenderResult(
                image: nil,
                displayText: "请输入公式标签",
                hasError: false,
                errorMessage: nil,
                size: nil
            )
        }
        
        do {
            // 使用 eMathica 的渲染器生成 LaTeX 图片
            let normalizedLatex = renderer.normalize(trimmed)
            let renderedImage = try renderer.renderToImage(normalizedLatex, fontSize: fontSize)
            
            return LatexRenderResult(
                image: renderedImage,
                displayText: normalizedLatex,
                hasError: false,
                errorMessage: nil,
                size: nil
            )
        } catch {
            // 渲染失败时返回文本降级
            return LatexRenderResult(
                image: nil,
                displayText: trimmed,
                hasError: true,
                errorMessage: "渲染失败: \(error.localizedDescription)",
                size: nil
            )
        }
    }
}

/// 文本替换渲染器（降级方案）
class TextSubstitutionRenderService: LatexRenderService {
    /// 降级方案使用 ¤ 作为 frac 的占位符号，与主预览保持一致
    private let fallbackReplacements: [(String, String)] = [
        ("\\left", ""), ("\\right", ""),
        ("\\times", "×"), ("\\div", "÷"),
        ("\\le", "≤"), ("\\ge", "≥"), ("\\ne", "≠"),
        ("\\alpha", "α"), ("\\beta", "β"), ("\\theta", "θ"),
        ("\\lambda", "λ"), ("\\pi", "π"), ("\\infty", "∞"),
        ("\\pm", "±"), ("\\partial", "∂"),
        ("\\in", "∈"), ("\\notin", "∉"),
        ("\\cap", "∩"), ("\\cup", "∪"), ("\\emptyset", "∅"),
        ("\\sum", "Σ"), ("\\int", "∫"),
        ("\\frac", " "), ("\\sqrt", "√"),
        ("{", ""), ("}", ""), ("\\", "")
    ]
    
    func render(_ latex: String, fontSize: CGFloat) async throws -> LatexRenderResult {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return LatexRenderResult(
                image: nil,
                displayText: "请输入公式标签",
                hasError: false,
                errorMessage: nil,
                size: nil
            )
        }
        
        let formatted = applySubstitutions(trimmed)
        
        return LatexRenderResult(
            image: nil,
            displayText: formatted,
            hasError: false,
            errorMessage: nil,
            size: nil
        )
    }
    
    private func applySubstitutions(_ raw: String) -> String {
        var result = raw
        for (from, to) in fallbackReplacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}

/// 渲染服务管理器
@MainActor
final class RenderServiceManager: ObservableObject {
    static let shared = RenderServiceManager()
    
    @Published private(set) var isRendering: Bool = false
    @Published private(set) var lastRenderResult: LatexRenderResult?
    
    private let primaryService: LatexRenderService
    private let fallbackService: LatexRenderService
    
    init() {
        self.primaryService = EMathicaMathRenderService()
        self.fallbackService = TextSubstitutionRenderService()
    }
    
    func render(_ latex: String, fontSize: CGFloat = 28) async {
        isRendering = true
        
        do {
            var result = try await primaryService.render(latex, fontSize: fontSize)
            
            if result.hasError {
                result = try await fallbackService.render(latex, fontSize: fontSize)
            }
            
            await MainActor.run {
                self.lastRenderResult = result
                self.isRendering = false
            }
        } catch {
            await MainActor.run {
                self.lastRenderResult = LatexRenderResult(
                    image: nil,
                    displayText: latex,
                    hasError: true,
                    errorMessage: "渲染失败: \(error.localizedDescription)",
                    size: nil
                )
                self.isRendering = false
            }
        }
    }
    
    func reset() {
        lastRenderResult = nil
    }
}

// MARK: - MathRenderer 扩展（利用 eMathica 的渲染能力）

extension MathRenderer {
    /// 将 LaTeX 渲染为 SwiftUI Image
    func renderToImage(_ latex: String, fontSize: CGFloat) throws -> Image? {
        #if canImport(UIKit)
        let image = renderToUIImage(latex, fontSize: fontSize)
        return image.map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        let image = renderToNSImage(latex, fontSize: fontSize)
        return image.map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }
    
    #if canImport(UIKit)
    private func renderToUIImage(_ latex: String, fontSize: CGFloat) -> UIImage? {
        let formatted = normalizeAndFormat(latex)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let attributedString = NSAttributedString(string: formatted, attributes: attributes)
        let textSize = attributedString.size()
        let padding: CGFloat = 12
        let imageSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        // 淡色背景
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(UIColor.secondarySystemBackground.cgColor)
            context.fill(CGRect(origin: .zero, size: imageSize))
        }
        
        // 居中绘制
        let textRect = CGRect(
            x: padding,
            y: (imageSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    #elseif canImport(AppKit)
    private func renderToNSImage(_ latex: String, fontSize: CGFloat) -> NSImage? {
        let formatted = normalizeAndFormat(latex)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.label
        ]
        let attributedString = NSAttributedString(string: formatted, attributes: attributes)
        let textSize = attributedString.size()
        let padding: CGFloat = 12
        let imageSize = NSSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)
        
        return NSImage(size: imageSize, flipped: false) { rect in
            NSColor.controlBackgroundColor.setFill()
            rect.fill()
            let textRect = NSRect(
                x: padding,
                y: (imageSize.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            return true
        }
    }
    #endif
    
    /// 规范化 LaTeX 表达式（trim + 移除 \\left/\\right）
    func normalize(_ latex: String) -> String {
        latex.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 规范化 + 应用 Unicode 数学符号替换
    private func normalizeAndFormat(_ latex: String) -> String {
        let trimmed = normalize(latex)
        var result = trimmed
        for (from, to) in latexSymbolReplacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
