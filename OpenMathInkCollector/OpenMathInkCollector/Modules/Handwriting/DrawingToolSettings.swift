import Foundation
import PencilKit
import SwiftUI

/// 手写工具类型
enum DrawingToolType: String, Codable, CaseIterable {
    case pen = "pen"
    case marker = "marker"
    case pencil = "pencil"
    case eraser = "eraser"
    
    var displayName: String {
        switch self {
        case .pen: return "钢笔"
        case .marker: return "马克笔"
        case .pencil: return "铅笔"
        case .eraser: return "橡皮擦"
        }
    }
    
    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        }
    }
}

/// 手写工具设置
class DrawingToolSettings: ObservableObject {
    static let shared = DrawingToolSettings()
    
    @Published var toolType: DrawingToolType = .pen
    @Published var colorIndex: Int = 0
    @Published var thicknessIndex: Int = 1
    
    /// 预设颜色
    let colors: [Color] = [
        Color(white: 0.1),      // 深灰
        Color(red: 0.8, green: 0.1, blue: 0.1),  // 红色
        Color(red: 0.1, green: 0.5, blue: 0.8),  // 蓝色
        Color(red: 0.1, green: 0.6, blue: 0.1),  // 绿色
        Color(red: 0.9, green: 0.6, blue: 0.1),  // 橙色
        Color(red: 0.6, green: 0.2, blue: 0.8),  // 紫色
    ]
    
    /// 预设笔画粗细
    let thicknessLevels: [CGFloat] = [1.5, 3.0, 4.5, 6.0, 8.0]
    
    /// 当前颜色
    var currentColor: Color {
        guard colorIndex >= 0 && colorIndex < colors.count else {
            return colors[0]
        }
        return colors[colorIndex]
    }

    /// 当前笔画粗细
    var currentThickness: CGFloat {
        guard thicknessIndex >= 0 && thicknessIndex < thicknessLevels.count else {
            return thicknessLevels[0]
        }
        return thicknessLevels[thicknessIndex]
    }
    
    /// 获取 PKTool
    func pkTool() -> PKTool {
        switch toolType {
        case .eraser:
            return PKEraserTool(.vector)
        case .pen:
            return PKInkingTool(.pen, color: uiColor(currentColor), width: currentThickness)
        case .marker:
            return PKInkingTool(.marker, color: uiColor(currentColor), width: currentThickness * 2)
        case .pencil:
            return PKInkingTool(.pencil, color: uiColor(currentColor), width: currentThickness * 0.8)
        }
    }
    
    /// 切换工具
    func setTool(_ tool: DrawingToolType) {
        toolType = tool
        saveSettings()
    }
    
    /// 设置颜色
    func setColor(at index: Int) {
        if index >= 0 && index < colors.count {
            colorIndex = index
            saveSettings()
        }
    }
    
    /// 设置笔画粗细
    func setThickness(at index: Int) {
        if index >= 0 && index < thicknessLevels.count {
            thicknessIndex = index
            saveSettings()
        }
    }
    
    private func uiColor(_ color: Color) -> UIColor {
        #if canImport(UIKit)
        return UIColor(color)
        #elseif canImport(AppKit)
        return UIColor(cgColor: NSColor(color).cgColor) ?? .label
        #endif
    }
    
    private func saveSettings() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: "DrawingToolSettings")
        } catch {
            print("[DrawingToolSettings] 设置保存失败: \(error)")
        }
    }
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "DrawingToolSettings") else { return }
        
        let decoder = JSONDecoder()
        do {
            let settings = try decoder.decode(DrawingToolSettings.self, from: data)
            self.toolType = settings.toolType
            self.colorIndex = settings.colorIndex
            self.thicknessIndex = settings.thicknessIndex
        } catch {
            print("[DrawingToolSettings] 设置加载失败: \(error)")
        }
    }
}

// MARK: - DrawingToolSettings Codable

extension DrawingToolSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case toolType
        case colorIndex
        case thicknessIndex
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolType, forKey: .toolType)
        try container.encode(colorIndex, forKey: .colorIndex)
        try container.encode(thicknessIndex, forKey: .thicknessIndex)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.toolType = try container.decode(DrawingToolType.self, forKey: .toolType)
        self.colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        self.thicknessIndex = try container.decode(Int.self, forKey: .thicknessIndex)
    }
}
