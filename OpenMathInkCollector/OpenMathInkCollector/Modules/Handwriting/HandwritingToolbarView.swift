import SwiftUI
import PencilKit

struct HandwritingToolbarView: View {
    @ObservedObject private var toolSettings = DrawingToolSettings.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 工具选择
            HStack(spacing: 8) {
                ForEach(DrawingToolType.allCases, id: \.rawValue) { tool in
                    ToolButton(
                        type: tool,
                        isSelected: toolSettings.toolType == tool
                    ) {
                        toolSettings.setTool(tool)
                    }
                }
            }
            
            // 分隔线
            Divider()
                .background(Color.secondary.opacity(0.3))
            
            // 颜色选择
            HStack(spacing: 6) {
                ForEach(toolSettings.colors.indices, id: \.self) { index in
                    ColorButton(
                        color: toolSettings.colors[index],
                        isSelected: toolSettings.colorIndex == index
                    ) {
                        toolSettings.setColor(at: index)
                    }
                }
            }
            
            // 笔画粗细
            HStack(spacing: 8) {
                Text("粗细")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(toolSettings.thicknessLevels.indices, id: \.self) { index in
                    ThicknessButton(
                        thickness: toolSettings.thicknessLevels[index],
                        isSelected: toolSettings.thicknessIndex == index
                    ) {
                        toolSettings.setThickness(at: index)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 工具按钮

private struct ToolButton: View {
    let type: DrawingToolType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                
                Text(type.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .foregroundStyle(isSelected ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 颜色按钮

private struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - 粗细按钮

private struct ThicknessButton: View {
    let thickness: CGFloat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                
                // 粗细指示
                Circle()
                    .fill(isSelected ? .blue : .secondary)
                    .frame(width: thickness * 2, height: thickness * 2)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

#Preview {
    HandwritingToolbarView()
        .preferredColorScheme(.dark)
}
