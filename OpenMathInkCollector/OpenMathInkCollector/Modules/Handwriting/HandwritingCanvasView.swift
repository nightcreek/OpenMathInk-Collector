import SwiftUI
import PencilKit

struct HandwritingCanvasView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("手写公式")
                        .font(.title3.weight(.semibold))
                    Text("用 Apple Pencil 或触控笔直接书写公式，尽量保持单条样本只包含一个清晰表达式。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            
            PencilDrawingRepresentable(
                drawingData: $workspace.currentDrawingData,
                canvasSize: $workspace.currentCanvasSize
            ) { drawing, size in
                workspace.updateCurrentDrawing(drawing, canvasSize: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.03),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .overlay(alignment: .center) {
                if !workspace.hasHandwriting {
                    VStack(spacing: 8) {
                        Image(systemName: "applepencil.tip")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("在这里书写公式")
                            .font(.headline)
                        Text("左侧专注手写，右侧录入结构化公式标签")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            
            // 工具操作栏
            HStack(spacing: 12) {
                HandwritingToolbarView()
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        workspace.clearCurrentDrawing()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        workspace.saveCurrentDraft()
                    } label: {
                        Label("保存草稿", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .collectorCardStyle()
    }
    
    private var statusBadge: some View {
        let status = workspace.selectedSample?.status ?? .draft
        return HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.18))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}
