import EMathicaFormulaDisplayCore
import EMathicaFormulaDisplaySwiftUI
import EMathicaThemeKit
import SwiftUI

struct LatexPreviewView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState

    private var matchHint: String {
        if !workspace.hasHandwriting {
            return "请先书写公式"
        }
        if !workspace.hasFormulaLabel {
            return "请先录入公式标签"
        }
        return "请确认手写内容与公式标签一致"
    }

    private var readinessTitle: String {
        workspace.hasHandwriting && workspace.hasFormulaLabel
            ? "可以确认样本"
            : "等待补全"
    }

    var body: some View {
        LiquidGlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标签预览")
                            .font(.title3.weight(.semibold))
                        Text("结构化公式标签的共享渲染结果")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    readinessBadge
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("标准公式")
                        .font(.headline)
                    formulaPreview
                        .padding(16)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 88,
                            alignment: .leading
                        )
                        .background(Color.black.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    Label(
                        matchHint,
                        systemImage: workspace.hasHandwriting && workspace.hasFormulaLabel
                            ? "checkmark.seal.fill"
                            : "exclamationmark.circle"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        workspace.hasHandwriting && workspace.hasFormulaLabel
                            ? Color.green
                            : Color.orange
                    )
                    .lineLimit(1)

                    Spacer()

                    Label(
                        workspace.selectedSample?.status.displayName ?? "草稿",
                        systemImage: "square.stack.3d.up.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)

                    Button {
                        workspace.clearFormulaInput()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("清空公式标签")
                }
            }
        }
    }

    @ViewBuilder
    private var formulaPreview: some View {
        if workspace.hasFormulaLabel {
            ScrollView(.horizontal, showsIndicators: false) {
                FormulaDisplayView(
                    document: workspace.formulaDisplayDocument,
                    style: FormulaDisplayStyle(
                        baseFont: .system(size: 28),
                        scriptScale: 0.64
                    ),
                    options: FormulaDisplayOptions(
                        cursorVisible: true,
                        renderingBackend: .swiftMath
                    ),
                    metrics: FormulaLayoutMetrics(baseFontSize: 28)
                )
                .fixedSize()
            }
        } else {
            Text("尚未输入公式标签")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var readinessBadge: some View {
        Text(readinessTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (workspace.hasHandwriting && workspace.hasFormulaLabel
                    ? Color.green
                    : Color.orange)
                    .opacity(0.18)
            )
            .foregroundStyle(
                workspace.hasHandwriting && workspace.hasFormulaLabel
                    ? Color.green
                    : Color.orange
            )
            .clipShape(Capsule())
    }

}
