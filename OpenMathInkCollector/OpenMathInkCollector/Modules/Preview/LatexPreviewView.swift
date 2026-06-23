import SwiftUI

struct LatexPreviewView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState

    private var previewText: String {
        let latex = workspace.currentLatex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !latex.isEmpty { return latex }
        return workspace.currentSourceText
    }

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
        if workspace.hasHandwriting && workspace.hasFormulaLabel {
            return "可以确认样本"
        }
        return "等待补全"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标签预览")
                        .font(.title3.weight(.semibold))
                    Text("右侧展示结构化公式标签的当前结果，用来和手写内容逐项核对。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                readinessBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("标准公式")
                    .font(.headline)
                FormulaLabelPreviewView(
                    text: previewText,
                    emptyText: "尚未输入公式标签",
                    fontSize: 28,
                    showsTemporaryCaption: true,
                    showsCaret: workspace.hasFormulaLabel
                )
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .background(Color.black.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 12) {
                stateCard(
                    title: "匹配状态",
                    body: matchHint,
                    systemImage: workspace.hasHandwriting && workspace.hasFormulaLabel ? "checkmark.seal.fill" : "exclamationmark.circle",
                    tint: workspace.hasHandwriting && workspace.hasFormulaLabel ? .green : .orange
                )
                stateCard(
                    title: "当前样本",
                    body: workspace.selectedSample?.status.displayName ?? "草稿",
                    systemImage: "square.stack.3d.up.fill",
                    tint: .blue
                )
            }

            HStack(spacing: 10) {
                Button("清空公式标签") {
                    workspace.clearFormulaInput()
                }
                .buttonStyle(.bordered)
                Spacer()
                if workspace.hasHandwriting && workspace.hasFormulaLabel {
                    Label("已满足确认条件", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .collectorCardStyle()
    }

    private var readinessBadge: some View {
        Text(readinessTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((workspace.hasHandwriting && workspace.hasFormulaLabel ? Color.green : Color.orange).opacity(0.18))
            .foregroundStyle(workspace.hasHandwriting && workspace.hasFormulaLabel ? Color.green : Color.orange)
            .clipShape(Capsule())
    }

    private func stateCard(title: String, body: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
